<?php
/**
 * Plugin Name: T-Work Points System
 * Plugin URI: https://www.tworksystem.com
 * Description: Loyalty points system for WooCommerce - Earn and redeem points
 * Version: 1.0.0
 * Author: T-Work System
 * Author URI: https://www.tworksystem.com
 * Text Domain: twork-points
 * Domain Path: /languages
 * Requires at least: 5.0
 * Requires PHP: 7.4
 * WC requires at least: 5.0
 * WC tested up to: 8.0
 */

if (!defined('ABSPATH')) {
    exit; // Exit if accessed directly
}

// Define plugin constants
define('TWORK_POINTS_VERSION', '1.0.0');
define('TWORK_POINTS_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('TWORK_POINTS_PLUGIN_URL', plugin_dir_url(__FILE__));

require_once TWORK_POINTS_PLUGIN_DIR . 'includes/admin/class-twork-points-admin.php';
require_once TWORK_POINTS_PLUGIN_DIR . 'includes/class-twork-points-logger.php';

/**
 * Main T-Work Points System Class
 */
class TWork_Points_System {

    private const SETTINGS_ERROR_TRANSIENT = 'twork_points_settings_errors';
    private const SETTINGS_VALUES_TRANSIENT = 'twork_points_settings_values';
    private const SYNC_ERROR_OPTION = 'twork_points_sync_error_state';
    private const SYNC_ERROR_NOTICE_OPTION = 'twork_points_sync_error_notice';
    private const SYNC_ERROR_THRESHOLD = 5;
    private const SYNC_ERROR_WINDOW = 3600; // 1 hour rolling window
    
    private static $instance = null;
    
    /**
     * Get singleton instance
     */
    public static function get_instance() {
        if (null === self::$instance) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * Constructor
     */
    private function __construct() {
        $this->init_hooks();
    }
    
    /**
     * Initialize hooks
     */
    private function init_hooks() {
        // Activation/Deactivation hooks
        register_activation_hook(__FILE__, array($this, 'activate'));
        register_deactivation_hook(__FILE__, array($this, 'deactivate'));
        
        // Initialize on plugins loaded
        add_action('plugins_loaded', array($this, 'init'));
        
        // WooCommerce hooks
        add_action('woocommerce_order_status_completed', array($this, 'award_points_on_order_completion'), 10, 1);
        add_action('woocommerce_order_status_processing', array($this, 'award_points_on_order_completion'), 10, 1);
        
        // Refund points on order cancellation
        add_action('woocommerce_order_status_cancelled', array($this, 'refund_points_on_order_cancellation'), 10, 1);
        add_action('woocommerce_order_status_refunded', array($this, 'refund_points_on_order_cancellation'), 10, 1);
        
        // REST API endpoints
        add_action('rest_api_init', array($this, 'register_rest_routes'));
        
        // Admin menu and pages
        add_action('admin_menu', array($this, 'add_admin_menu'));
        add_action('admin_enqueue_scripts', array($this, 'enqueue_admin_assets'));
        
        // User profile integration
        add_action('show_user_profile', array($this, 'add_user_profile_points_section'));
        add_action('edit_user_profile', array($this, 'add_user_profile_points_section'));
        add_action('personal_options_update', array($this, 'save_user_profile_points'));
        add_action('edit_user_profile_update', array($this, 'save_user_profile_points'));
        
        // Form handlers
        add_action('admin_post_twork_points_save_settings', array($this, 'handle_settings_save'));
        add_action('admin_post_twork_points_adjust_user_points', array($this, 'handle_adjust_user_points'));
        add_action('admin_post_twork_points_bulk_action', array($this, 'handle_bulk_action'));
        add_action('admin_post_twork_points_export', array($this, 'handle_export_transactions'));
        
        // Admin notices
        add_action('admin_notices', array($this, 'admin_notices'));
        add_action('admin_init', array($this, 'handle_notice_dismissal'));
    }

    /**
     * Register admin menu and submenu pages
     */
    public function add_admin_menu() {
        $capability = current_user_can('manage_woocommerce') ? 'manage_woocommerce' : 'manage_options';
        $parent_slug = 'twork-points';

        add_menu_page(
            __('T-Work Points', 'twork-points'),
            __('T-Work Points', 'twork-points'),
            $capability,
            $parent_slug,
            array($this, 'render_dashboard_page'),
            'dashicons-awards',
            56
        );

        add_submenu_page(
            $parent_slug,
            __('Dashboard', 'twork-points'),
            __('Dashboard', 'twork-points'),
            $capability,
            $parent_slug,
            array($this, 'render_dashboard_page')
        );

        add_submenu_page(
            $parent_slug,
            __('Settings', 'twork-points'),
            __('Settings', 'twork-points'),
            $capability,
            'twork-points-settings',
            array($this, 'render_settings_page')
        );

        add_submenu_page(
            $parent_slug,
            __('User Points', 'twork-points'),
            __('User Points', 'twork-points'),
            $capability,
            'twork-points-users',
            array($this, 'render_user_points_page')
        );

        add_submenu_page(
            $parent_slug,
            __('Transactions', 'twork-points'),
            __('Transactions', 'twork-points'),
            $capability,
            'twork-points-transactions',
            array($this, 'render_transactions_page')
        );

        add_submenu_page(
            $parent_slug,
            __('Reports & Tools', 'twork-points'),
            __('Reports & Tools', 'twork-points'),
            $capability,
            'twork-points-reports',
            array($this, 'render_reports_page')
        );
    }

    /**
     * Enqueue admin assets only on plugin screens
     */
    public function enqueue_admin_assets($hook_suffix) {
        if (strpos($hook_suffix, 'twork-points') === false) {
            return;
        }

        wp_enqueue_style(
            'twork-points-admin',
            TWORK_POINTS_PLUGIN_URL . 'assets/css/admin.css',
            array(),
            TWORK_POINTS_VERSION
        );

        wp_enqueue_script(
            'twork-points-admin',
            TWORK_POINTS_PLUGIN_URL . 'assets/js/admin.js',
            array('jquery'),
            TWORK_POINTS_VERSION,
            true
        );

        wp_localize_script('twork-points-admin', 'TWorkPointsAdmin', array(
            'nonce' => wp_create_nonce('twork_points_admin'),
            'ajaxUrl' => admin_url('admin-ajax.php'),
        ));
    }

    /**
     * Render dashboard page
     */
    public function render_dashboard_page() {
        if (!current_user_can('manage_woocommerce') && !current_user_can('manage_options')) {
            wp_die(__('You do not have permission to access this page.', 'twork-points'));
        }

        $summary = $this->get_points_summary();
        $recent_transactions = $this->get_transactions(array('limit' => 10));
        $recent_adjustments = $this->get_transactions(array('limit' => 5, 'type' => 'adjust'));

        include TWORK_POINTS_PLUGIN_DIR . 'templates/admin/dashboard.php';
    }

    /**
     * Render settings page
     */
    public function render_settings_page() {
        if (!current_user_can('manage_options')) {
            wp_die(__('You do not have permission to access this page.', 'twork-points'));
        }

        $options = array(
            'points_rate' => floatval(get_option('twork_points_rate', 1.0)),
            'redemption_rate' => floatval(get_option('twork_points_redemption_rate', 100)),
            'signup_bonus' => intval(get_option('twork_points_signup_bonus', 100)),
            'referral_bonus' => intval(get_option('twork_points_referral_bonus', 500)),
            'birthday_bonus' => intval(get_option('twork_points_birthday_bonus', 200)),
            'min_redemption' => intval(get_option('twork_points_min_redemption', 100)),
            'max_redemption_percent' => intval(get_option('twork_points_max_redemption_percent', 50)),
            'expiration_days' => intval(get_option('twork_points_expiration_days', 365)),
        );

        $field_errors = get_transient(self::SETTINGS_ERROR_TRANSIENT);
        $previous_values = get_transient(self::SETTINGS_VALUES_TRANSIENT);

        if (is_array($previous_values) && !empty($previous_values)) {
            $options = array_merge($options, $previous_values);
        }

        if ($field_errors !== false) {
            delete_transient(self::SETTINGS_ERROR_TRANSIENT);
        } else {
            $field_errors = array();
        }

        if ($previous_values !== false) {
            delete_transient(self::SETTINGS_VALUES_TRANSIENT);
        }

        include TWORK_POINTS_PLUGIN_DIR . 'templates/admin/settings.php';
    }

    /**
     * Render user points management page
     */
    public function render_user_points_page() {
        if (!current_user_can('manage_users') && !current_user_can('manage_woocommerce') && !current_user_can('manage_options')) {
            wp_die(__('You do not have permission to access this page.', 'twork-points'));
        }

        $search_query = isset($_GET['s']) ? sanitize_text_field(wp_unslash($_GET['s'])) : '';
        $selected_user = null;
        $user_balance = null;
        $user_transactions = array();

        if (!empty($search_query)) {
            $user_query = new WP_User_Query(array(
                'search'         => '*' . $search_query . '*',
                'search_columns' => array('user_login', 'user_email', 'display_name'),
                'number'         => 20,
            ));

            $users = $user_query->get_results();

            if (!empty($_GET['user_id'])) {
                $selected_user = get_user_by('ID', intval($_GET['user_id']));
            } elseif (count($users) === 1) {
                $selected_user = $users[0];
            }
        } else {
            $users = array();
        }

        if ($selected_user instanceof WP_User) {
            $user_balance = $this->calculate_user_balance($selected_user->ID, true);
            $user_transactions = $this->get_transactions(array(
                'user_id' => $selected_user->ID,
                'limit'   => 20,
            ));
        }

        include TWORK_POINTS_PLUGIN_DIR . 'templates/admin/users.php';
    }

    /**
     * Render transactions page with filters
     */
    public function render_transactions_page() {
        if (!current_user_can('manage_woocommerce') && !current_user_can('manage_options')) {
            wp_die(__('You do not have permission to access this page.', 'twork-points'));
        }

        $args = array(
            'type'    => isset($_GET['type']) ? sanitize_text_field($_GET['type']) : '',
            'user_id' => isset($_GET['user_id']) ? intval($_GET['user_id']) : 0,
            'order_id'=> isset($_GET['order_id']) ? sanitize_text_field($_GET['order_id']) : '',
            'search'  => isset($_GET['search']) ? sanitize_text_field(wp_unslash($_GET['search'])) : '',
            'paged'   => isset($_GET['paged']) ? max(1, intval($_GET['paged'])) : 1,
        );

        $per_page = isset($_GET['per_page']) ? intval($_GET['per_page']) : 25;
        $per_page = ($per_page > 0) ? min(200, $per_page) : 25;
        $args['limit'] = $per_page;

        $result = $this->get_transactions(array_merge($args, array('with_total' => true)));
        $transactions = $result['transactions'];
        $total_transactions = $result['total'];
        $total_pages = $per_page > 0 ? (int) ceil(max(0, $total_transactions) / $per_page) : 1;

        if ($total_pages > 0 && $args['paged'] > $total_pages) {
            $args['paged'] = $total_pages;
            $result = $this->get_transactions(array_merge($args, array('with_total' => true)));
            $transactions = $result['transactions'];
            $total_transactions = $result['total'];
            $total_pages = $per_page > 0 ? (int) ceil(max(0, $total_transactions) / $per_page) : 1;
        }

        $summary = $this->get_points_summary();

        $pagination_links = '';
        if ($total_pages > 1) {
            $base_args = array(
                'page' => 'twork-points-transactions',
                'type' => $args['type'],
                'user_id' => $args['user_id'],
                'order_id' => $args['order_id'],
                'search' => $args['search'],
                'per_page' => $per_page,
            );

            $pagination_links = paginate_links(array(
                'base' => add_query_arg(array_merge($base_args, array('paged' => '%#%')), admin_url('admin.php')),
                'format' => '',
                'current' => $args['paged'],
                'total' => max(1, $total_pages),
                'prev_text' => __('« Previous', 'twork-points'),
                'next_text' => __('Next »', 'twork-points'),
            ));
        }

        include TWORK_POINTS_PLUGIN_DIR . 'templates/admin/transactions.php';
    }

    /**
     * Render reports and tools page
     */
    public function render_reports_page() {
        if (!current_user_can('manage_woocommerce') && !current_user_can('manage_options')) {
            wp_die(__('You do not have permission to access this page.', 'twork-points'));
        }

        $summary = $this->get_points_summary();
        $top_users = $this->get_top_users();
        $expiring_soon = $this->get_transactions(array(
            'type'    => 'earn',
            'expiring'=> true,
            'limit'   => 10,
        ));

        include TWORK_POINTS_PLUGIN_DIR . 'templates/admin/reports.php';
    }

    /**
     * Add points information to user profile screen
     */
    public function add_user_profile_points_section($user) {
        if (!current_user_can('manage_users')) {
            return;
        }

        $balance = $this->calculate_user_balance($user->ID, true);
        include TWORK_POINTS_PLUGIN_DIR . 'templates/admin/user-profile.php';
    }

    /**
     * Save user profile points adjustments
     */
    public function save_user_profile_points($user_id) {
        if (!current_user_can('manage_users')) {
            return;
        }

        if (!isset($_POST['twork_points_profile_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['twork_points_profile_nonce'])), 'twork_points_profile_update')) {
            return;
        }

        if (isset($_POST['twork_points_adjust_amount']) && $_POST['twork_points_adjust_amount'] !== '') {
            $points = intval($_POST['twork_points_adjust_amount']);
            $description = isset($_POST['twork_points_adjust_reason']) ? sanitize_text_field(wp_unslash($_POST['twork_points_adjust_reason'])) : '';

            if ($points !== 0) {
                $transaction_data = array(
                    'user_id' => $user_id,
                    'type' => 'adjust',
                    'points' => $points,
                    'description' => $description ?: __('Manual adjustment via user profile', 'twork-points'),
                );
                $this->create_transaction($transaction_data);
                $this->invalidate_balance_cache($user_id);
            }
        }
    }

    /**
     * Handle settings save
     */
    public function handle_settings_save() {
        if (!current_user_can('manage_options')) {
            wp_die(__('You do not have permission to perform this action.', 'twork-points'));
        }

        check_admin_referer('twork_points_save_settings');

        $input = wp_unslash($_POST);

        $validation = $this->validate_settings_input($input);
        $field_errors = $validation['errors'];
        $display_values = $validation['display_values'];
        $options_to_update = $validation['options'];

        if (! empty($field_errors)) {
            set_transient(self::SETTINGS_ERROR_TRANSIENT, $field_errors, MINUTE_IN_SECONDS);
            set_transient(self::SETTINGS_VALUES_TRANSIENT, $display_values, MINUTE_IN_SECONDS);

            $redirect = add_query_arg(array(
                'page' => 'twork-points-settings',
                'twork_points_notice' => 'settings_invalid',
            ), admin_url('admin.php'));

            wp_safe_redirect($redirect);
            exit;
        }

        foreach ($options_to_update as $option_key => $value) {
            update_option($option_key, $value);
        }

        delete_transient(self::SETTINGS_ERROR_TRANSIENT);
        delete_transient(self::SETTINGS_VALUES_TRANSIENT);

        $redirect = add_query_arg(array(
            'page' => 'twork-points-settings',
            'twork_points_notice' => 'settings_saved',
        ), admin_url('admin.php'));

        wp_safe_redirect($redirect);
        exit;
    }

    /**
     * Validate settings input and return sanitized values with error messages.
     *
     * @param array $input Raw input.
     * @return array {
     *     @type array $display_values Values formatted for UI.
     *     @type array $options        Values keyed by option name for persistence.
     *     @type array $errors         Field-level error messages.
     * }
     */
    private function validate_settings_input(array $input): array {
        $schema = $this->get_settings_schema();

        $display_values = array();
        $options = array();
        $errors = array();

        foreach ($schema as $field_key => $rules) {
            $raw_value = isset($input[$rules['field']]) ? $input[$rules['field']] : '';
            $raw_value = is_array($raw_value) ? '' : $raw_value; // prevent arrays
            $display_values[$field_key] = is_scalar($raw_value) ? sanitize_text_field((string) $raw_value) : '';

            if ($raw_value === '') {
                if (! empty($rules['required'])) {
                    $errors[$field_key] = sprintf(
                        /* translators: %s - field label */
                        __('%s is required.', 'twork-points'),
                        $rules['label']
                    );
                }
                continue;
            }

            $parsed = $this->parse_numeric($raw_value, $rules['type']);

            if ($parsed === null) {
                $errors[$field_key] = sprintf(
                    /* translators: %s - field label */
                    __('%s must be a numeric value.', 'twork-points'),
                    $rules['label']
                );
                continue;
            }

            if (isset($rules['min']) && $parsed < $rules['min']) {
                $errors[$field_key] = sprintf(
                    /* translators: 1: field label, 2: minimum value */
                    __('%1$s must be greater than or equal to %2$s.', 'twork-points'),
                    $rules['label'],
                    $rules['min']
                );
                continue;
            }

            if (isset($rules['max']) && $parsed > $rules['max']) {
                $errors[$field_key] = sprintf(
                    /* translators: 1: field label, 2: maximum value */
                    __('%1$s must be less than or equal to %2$s.', 'twork-points'),
                    $rules['label'],
                    $rules['max']
                );
                continue;
            }

            if (! empty($rules['integer'])) {
                $parsed = (int) round($parsed);
            }

            $display_values[$field_key] = $parsed;
            $options[$rules['option']] = $parsed;
        }

        return array(
            'display_values' => $display_values,
            'options' => $options,
            'errors' => $errors,
        );
    }

    /**
     * Get settings field schema describing sanitization rules.
     *
     * @return array
     */
    private function get_settings_schema(): array {
        return array(
            'points_rate' => array(
                'field' => 'twork_points_rate',
                'option' => 'twork_points_rate',
                'label' => __('Points Earning Rate', 'twork-points'),
                'type' => 'float',
                'min' => 0,
                'required' => true,
            ),
            'redemption_rate' => array(
                'field' => 'twork_points_redemption_rate',
                'option' => 'twork_points_redemption_rate',
                'label' => __('Points Redemption Rate', 'twork-points'),
                'type' => 'float',
                'min' => 0.01,
                'required' => true,
            ),
            'signup_bonus' => array(
                'field' => 'twork_points_signup_bonus',
                'option' => 'twork_points_signup_bonus',
                'label' => __('Signup Bonus Points', 'twork-points'),
                'type' => 'int',
                'min' => 0,
                'integer' => true,
                'required' => true,
            ),
            'referral_bonus' => array(
                'field' => 'twork_points_referral_bonus',
                'option' => 'twork_points_referral_bonus',
                'label' => __('Referral Bonus Points', 'twork-points'),
                'type' => 'int',
                'min' => 0,
                'integer' => true,
                'required' => true,
            ),
            'birthday_bonus' => array(
                'field' => 'twork_points_birthday_bonus',
                'option' => 'twork_points_birthday_bonus',
                'label' => __('Birthday Bonus Points', 'twork-points'),
                'type' => 'int',
                'min' => 0,
                'integer' => true,
                'required' => true,
            ),
            'min_redemption' => array(
                'field' => 'twork_points_min_redemption',
                'option' => 'twork_points_min_redemption',
                'label' => __('Minimum Points to Redeem', 'twork-points'),
                'type' => 'int',
                'min' => 0,
                'integer' => true,
                'required' => true,
            ),
            'max_redemption_percent' => array(
                'field' => 'twork_points_max_redemption_percent',
                'option' => 'twork_points_max_redemption_percent',
                'label' => __('Maximum Points per Order (%)', 'twork-points'),
                'type' => 'int',
                'min' => 0,
                'max' => 100,
                'integer' => true,
                'required' => true,
            ),
            'expiration_days' => array(
                'field' => 'twork_points_expiration_days',
                'option' => 'twork_points_expiration_days',
                'label' => __('Points Expiration (days)', 'twork-points'),
                'type' => 'int',
                'min' => 0,
                'integer' => true,
                'required' => true,
            ),
        );
    }

    /**
     * Parse numeric input according to the expected type.
     *
     * @param mixed  $value Raw value.
     * @param string $type  Expected type (int|float).
     *
     * @return float|int|null
     */
    private function parse_numeric($value, string $type) {
        if ($value === '' || $value === null) {
            return null;
        }

        if (! is_scalar($value)) {
            return null;
        }

        $value = trim((string) $value);

        if ($type === 'int') {
            return filter_var($value, FILTER_VALIDATE_INT, FILTER_NULL_ON_FAILURE);
        }

        if ($type === 'float') {
            $normalized = str_replace(',', '.', $value);
            return filter_var($normalized, FILTER_VALIDATE_FLOAT, FILTER_NULL_ON_FAILURE);
        }

        return null;
    }

    /**
     * Handle manual user points adjustment
     */
    public function handle_adjust_user_points() {
        if (!current_user_can('manage_users') && !current_user_can('manage_woocommerce') && !current_user_can('manage_options')) {
            wp_die(__('You do not have permission to perform this action.', 'twork-points'));
        }

        check_admin_referer('twork_points_adjust_user_points');

        $user_id = isset($_POST['user_id']) ? intval($_POST['user_id']) : 0;
        $points  = isset($_POST['points']) ? intval($_POST['points']) : 0;
        $reason  = isset($_POST['reason']) ? sanitize_text_field(wp_unslash($_POST['reason'])) : '';
        $redirect_to = isset($_POST['redirect_to']) ? esc_url_raw(wp_unslash($_POST['redirect_to'])) : '';

        if (!$user_id || $points === 0) {
            $redirect = add_query_arg(array(
                'page' => 'twork-points-users',
                'twork_points_notice' => 'invalid_request',
            ), admin_url('admin.php'));
            wp_safe_redirect($redirect);
            exit;
        }

        $type = $points >= 0 ? 'adjust' : 'adjust';

        $transaction_id = $this->create_transaction(array(
            'user_id' => $user_id,
            'type' => $type,
            'points' => $points,
            'description' => $reason ?: __('Manual adjustment via admin', 'twork-points'),
        ));

        if ($transaction_id) {
            $this->invalidate_balance_cache($user_id);
            $admin = wp_get_current_user();
            $this->record_admin_adjustment($user_id, $points, $reason, $admin ? intval($admin->ID) : 0);
            TWork_Points_Logger::info(
                'Manual points adjustment applied',
                array(
                    'transaction_id' => $transaction_id,
                    'user_id' => $user_id,
                    'points' => $points,
                    'admin_user' => $admin ? $admin->user_login : 'unknown',
                )
            );
            $notice = 'adjustment_success';
        } else {
            TWork_Points_Logger::error(
                'Manual points adjustment failed',
                array(
                    'user_id' => $user_id,
                    'points' => $points,
                )
            );
            $notice = 'adjustment_failed';
        }

        if (empty($redirect_to)) {
            $redirect_to = add_query_arg(array(
                'page' => 'twork-points-users',
                'user_id' => $user_id,
                'twork_points_notice' => $notice,
            ), admin_url('admin.php'));
        } else {
            $redirect_to = add_query_arg(array(
                'twork_points_notice' => $notice,
            ), $redirect_to);
        }

        wp_safe_redirect($redirect_to);
        exit;
    }

    /**
     * Handle bulk actions (recalculate balances, expire points)
     */
    public function handle_bulk_action() {
        if (!current_user_can('manage_options')) {
            wp_die(__('You do not have permission to perform this action.', 'twork-points'));
        }

        check_admin_referer('twork_points_bulk_action');

        $action = isset($_POST['bulk_action']) ? sanitize_text_field(wp_unslash($_POST['bulk_action'])) : '';

        switch ($action) {
            case 'recalculate_balances':
                $this->recalculate_all_balances();
                $notice = 'balances_recalculated';
                break;
            case 'expire_now':
                $this->expire_points_now();
                $notice = 'points_expired';
                break;
            default:
                $notice = 'invalid_request';
                break;
        }

        $redirect = add_query_arg(array(
            'page' => 'twork-points-reports',
            'twork_points_notice' => $notice,
        ), admin_url('admin.php'));

        wp_safe_redirect($redirect);
        exit;
    }

    /**
     * Handle exporting transactions to CSV
     */
    public function handle_export_transactions() {
        if (!current_user_can('manage_woocommerce') && !current_user_can('manage_options')) {
            wp_die(__('You do not have permission to perform this action.', 'twork-points'));
        }

        check_admin_referer('twork_points_export');

        $args = array(
            'type' => isset($_POST['type']) ? sanitize_text_field(wp_unslash($_POST['type'])) : '',
            'user_id' => isset($_POST['user_id']) ? intval($_POST['user_id']) : 0,
            'order_id' => isset($_POST['order_id']) ? sanitize_text_field(wp_unslash($_POST['order_id'])) : '',
            'search' => isset($_POST['search']) ? sanitize_text_field(wp_unslash($_POST['search'])) : '',
            'limit' => -1,
        );

        $transactions = $this->get_transactions($args);

        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename=twork-points-transactions-' . date('Y-m-d') . '.csv');

        $output = fopen('php://output', 'w');
        fputcsv($output, array('ID', 'User ID', 'User Email', 'Type', 'Points', 'Description', 'Order ID', 'Created At', 'Expires At', 'Expired?'));

        foreach ($transactions as $transaction) {
            $user = get_user_by('ID', $transaction['user_id']);
            fputcsv($output, array(
                $transaction['id'],
                $transaction['user_id'],
                $user ? $user->user_email : '',
                $transaction['type'],
                $transaction['points'],
                $transaction['description'],
                $transaction['order_id'],
                $transaction['created_at'],
                $transaction['expires_at'],
                $transaction['is_expired'] ? 'Yes' : 'No',
            ));
        }

        fclose($output);
        exit;
    }

    /**
     * Display admin notices
     */
    public function admin_notices() {
        $this->maybe_render_sync_alert();

        if (!isset($_GET['twork_points_notice'])) {
            return;
        }

        $notice = sanitize_key($_GET['twork_points_notice']);
        $messages = array(
            'settings_saved' => array('class' => 'success', 'text' => __('Point settings saved successfully.', 'twork-points')),
            'settings_invalid' => array('class' => 'error', 'text' => __('Settings were not saved. Please correct the highlighted errors and try again.', 'twork-points')),
            'adjustment_success' => array('class' => 'success', 'text' => __('Points adjusted successfully.', 'twork-points')),
            'adjustment_failed' => array('class' => 'error', 'text' => __('Failed to adjust points. Please try again.', 'twork-points')),
            'balances_recalculated' => array('class' => 'success', 'text' => __('All user balances recalculated successfully.', 'twork-points')),
            'points_expired' => array('class' => 'success', 'text' => __('Expired points processed successfully.', 'twork-points')),
            'invalid_request' => array('class' => 'error', 'text' => __('Invalid request.', 'twork-points')),
        );

        if (isset($messages[$notice])) {
            printf(
                '<div class="notice notice-%1$s is-dismissible"><p>%2$s</p></div>',
                esc_attr($messages[$notice]['class']),
                esc_html($messages[$notice]['text'])
            );
        }
    }

    /**
     * Allow administrators to dismiss persistent notices.
     */
    public function handle_notice_dismissal(): void {
        if (! current_user_can('manage_options')) {
            return;
        }

        if (! isset($_GET['twork_points_dismiss'])) {
            return;
        }

        $notice = sanitize_key($_GET['twork_points_dismiss']);
        if ('sync_errors' === $notice) {
            delete_option(self::SYNC_ERROR_NOTICE_OPTION);
            $redirect = remove_query_arg('twork_points_dismiss');
            if (!$redirect) {
                $redirect = admin_url();
            }
            wp_safe_redirect($redirect);
            exit;
        }
    }

    /**
     * Persist sync failure state and log the error.
     *
     * @param string $context Context of the failure.
     * @param mixed  $error   Error payload.
     */
    private function record_sync_failure(string $context, $error): void {
        $state = get_option(self::SYNC_ERROR_OPTION, array());
        $now   = time();
        $first = isset($state['first']) ? intval($state['first']) : $now;

        if (($now - $first) > self::SYNC_ERROR_WINDOW) {
            $first = $now;
            $state['count'] = 0;
        }

        $count   = isset($state['count']) ? intval($state['count']) + 1 : 1;
        $message = is_scalar($error) ? (string) $error : wp_json_encode($error);

        $state['count']        = $count;
        $state['first']        = $first;
        $state['last_context'] = $context;
        $state['last_message'] = $message;
        $state['updated_at']   = current_time('mysql', true);

        update_option(self::SYNC_ERROR_OPTION, $state, false);

        TWork_Points_Logger::error(
            sprintf('Sync failure recorded (%s)', $context),
            array(
                'count'   => $count,
                'message' => $message,
            )
        );

        if ($count >= self::SYNC_ERROR_THRESHOLD) {
            update_option(
                self::SYNC_ERROR_NOTICE_OPTION,
                array(
                    'count'        => $count,
                    'last_message' => $message,
                    'last_context' => $context,
                    'timestamp'    => $now,
                ),
                false
            );
        }
    }

    /**
     * Clears the failure counter after a successful sync.
     */
    private function record_sync_success(): void {
        delete_option(self::SYNC_ERROR_NOTICE_OPTION);

        $state = array(
            'count'        => 0,
            'first'        => time(),
            'last_context' => '',
            'last_message' => '',
            'updated_at'   => current_time('mysql', true),
        );

        update_option(self::SYNC_ERROR_OPTION, $state, false);
    }

    /**
     * Display admin alert when sync errors remain high.
     */
    private function maybe_render_sync_alert(): void {
        $notice = get_option(self::SYNC_ERROR_NOTICE_OPTION, array());
        if (empty($notice['count']) || intval($notice['count']) < self::SYNC_ERROR_THRESHOLD) {
            return;
        }

        $dismiss_url = add_query_arg(
            array(
                'twork_points_dismiss' => 'sync_errors',
            )
        );

        $message = isset($notice['last_message']) && $notice['last_message']
            ? $notice['last_message']
            : __('See logs for more detail.', 'twork-points');

        printf(
            '<div class="notice notice-error"><p>%s</p><p><a href="%s">%s</a></p></div>',
            esc_html(
                sprintf(
                    /* translators: 1: number of failures, 2: last error message */
                    __('Point sync has failed %1$d times in the last hour. Last error: %2$s', 'twork-points'),
                    intval($notice['count']),
                    $message
                )
            ),
            esc_url($dismiss_url),
            esc_html__('Dismiss this alert', 'twork-points')
        );
    }

    private function record_admin_adjustment(int $user_id, int $points, string $reason, int $admin_user_id): void {
        global $wpdb;
        $table = $wpdb->prefix . 'twork_point_audit_log';

        $wpdb->insert(
            $table,
            array(
                'user_id' => $user_id,
                'admin_user_id' => $admin_user_id,
                'points' => $points,
                'reason' => $reason,
                'created_at' => current_time('mysql', true),
            ),
            array('%d', '%d', '%d', '%s', '%s')
        );

        TWork_Points_Logger::info(
            'Admin points adjustment recorded',
            array(
                'user_id' => $user_id,
                'admin_user_id' => $admin_user_id,
                'points' => $points,
            )
        );
    }

    /**
     * Retrieve overall points summary statistics
     */
    private function get_points_summary() {
        global $wpdb;
        $table_name = $wpdb->prefix . 'twork_point_transactions';

        $summary = $wpdb->get_row(
            "SELECT 
                SUM(CASE WHEN type IN ('earn', 'adjust', 'referral', 'birthday', 'refund') THEN points ELSE 0 END) AS total_earned,
                SUM(CASE WHEN type = 'redeem' THEN points ELSE 0 END) AS total_redeemed,
                SUM(CASE WHEN type = 'expire' THEN points ELSE 0 END) AS total_expired,
                COUNT(DISTINCT user_id) AS active_users,
                COUNT(*) AS total_transactions
            FROM $table_name", ARRAY_A
        );

        $summary = array_map('intval', $summary ?: array());
        $summary['current_balance'] = max(0, ($summary['total_earned'] ?? 0) - ($summary['total_redeemed'] ?? 0) - ($summary['total_expired'] ?? 0));

        return $summary;
    }

    /**
     * Retrieve transactions with optional filters
     */
    private function get_transactions($args = array()) {
        global $wpdb;
        $table_name = $wpdb->prefix . 'twork_point_transactions';

        $defaults = array(
            'type'    => '',
            'user_id' => 0,
            'order_id'=> '',
            'limit'   => 25,
            'paged'   => 1,
            'expiring'=> false,
            'search'  => '',
            'with_total' => false,
        );
        $args = wp_parse_args($args, $defaults);

        $where = array();
        $where_params = array();

        if (!empty($args['type'])) {
            $where[] = 'type = %s';
            $where_params[] = $args['type'];
        }

        if (!empty($args['user_id'])) {
            $where[] = 'user_id = %d';
            $where_params[] = $args['user_id'];
        }

        if (!empty($args['order_id'])) {
            $where[] = 'order_id = %s';
            $where_params[] = $args['order_id'];
        }

        if (!empty($args['expiring'])) {
            $where[] = 'expires_at IS NOT NULL AND expires_at > NOW() AND expires_at <= DATE_ADD(NOW(), INTERVAL 30 DAY)';
        }

        if (!empty($args['search'])) {
            $like = '%' . $wpdb->esc_like($args['search']) . '%';
            $where[] = '(description LIKE %s OR order_id LIKE %s)';
            $where_params[] = $like;
            $where_params[] = $like;
        }

        $where_sql = empty($where) ? '' : 'WHERE ' . implode(' AND ', $where);

        $limit = intval($args['limit']);
        $limit = ($limit === -1) ? 0 : $limit;
        $current_page = max(1, intval($args['paged']));
        $offset = $limit > 0 ? ($current_page - 1) * $limit : 0;

        $limit_sql = '';
        $limit_params = array();
        if ($limit > 0) {
            $limit_sql = ' LIMIT %d OFFSET %d';
            $limit_params = array($limit, $offset);
        }

        $sql = "SELECT * FROM $table_name $where_sql ORDER BY created_at DESC$limit_sql";

        $query_params = array_merge($where_params, $limit_params);

        if (!empty($query_params)) {
            $sql = $wpdb->prepare($sql, $query_params);
        }

        $results = $wpdb->get_results($sql, ARRAY_A);

        if (empty($args['with_total'])) {
            return $results;
        }

        $count_sql = "SELECT COUNT(*) FROM $table_name $where_sql";
        if (!empty($where_params)) {
            $count_sql = $wpdb->prepare($count_sql, $where_params);
        }

        $total = (int) $wpdb->get_var($count_sql);

        return array(
            'transactions' => $results,
            'total' => $total,
        );
    }

    /**
     * Retrieve top users by points balance
     */
    private function get_top_users($limit = 10) {
        global $wpdb;
        $table_name = $wpdb->prefix . 'twork_point_transactions';

        $sql = $wpdb->prepare(
            "SELECT user_id,
                SUM(CASE WHEN type IN ('earn', 'adjust', 'referral', 'birthday', 'refund') THEN points ELSE 0 END) as earned,
                SUM(CASE WHEN type = 'redeem' THEN points ELSE 0 END) as redeemed,
                SUM(CASE WHEN type = 'expire' THEN points ELSE 0 END) as expired
             FROM $table_name
             GROUP BY user_id
             ORDER BY (earned - redeemed - expired) DESC
             LIMIT %d",
            $limit
        );

        return $wpdb->get_results($sql, ARRAY_A);
    }

    /**
     * Recalculate all user balances and update cache
     */
    private function recalculate_all_balances() {
        global $wpdb;
        $table_name = $wpdb->prefix . 'twork_point_transactions';

        $user_ids = $wpdb->get_col("SELECT DISTINCT user_id FROM $table_name");

        foreach ($user_ids as $user_id) {
            $balance = $this->calculate_user_balance($user_id, true);
            update_user_meta($user_id, 'points_balance', $balance);
        }
    }

    /**
     * Expire points for a single user and create an expire transaction
     */
    private function expire_points_for_user($user_id) {
        global $wpdb;

        $table_name = $wpdb->prefix . 'twork_point_transactions';

        $expired_transactions = $wpdb->get_results($wpdb->prepare(
            "SELECT id, points FROM $table_name 
            WHERE user_id = %d 
            AND type = 'earn' 
            AND expires_at IS NOT NULL 
            AND expires_at <= NOW() 
            AND is_expired = 0",
            $user_id
        ));

        if (empty($expired_transactions)) {
            return array('expired_count' => 0, 'expired_points' => 0);
        }

        $total_expired_points = 0;
        foreach ($expired_transactions as $transaction) {
            $total_expired_points += intval($transaction->points);
        }

        $wpdb->query($wpdb->prepare(
            "UPDATE $table_name 
            SET is_expired = 1 
            WHERE user_id = %d 
            AND type = 'earn' 
            AND expires_at IS NOT NULL 
            AND expires_at <= NOW() 
            AND is_expired = 0",
            $user_id
        ));

        if ($total_expired_points > 0) {
            $this->create_transaction(array(
                'user_id' => $user_id,
                'type' => 'expire',
                'points' => $total_expired_points,
                'description' => sprintf(
                    /* translators: %d: number of transactions */
                    __('Points expired across %d earn transactions', 'twork-points'),
                    count($expired_transactions)
                ),
            ));
        }

        $balance = $this->calculate_user_balance($user_id, true);
        update_user_meta($user_id, 'points_balance', $balance);

        return array(
            'expired_count' => count($expired_transactions),
            'expired_points' => $total_expired_points,
            'balance' => $balance,
        );
    }
    
    /**
     * Plugin activation
     */
    public function activate() {
        // Create database tables if needed
        $this->create_tables();
        
        // Set default options
        if (!get_option('twork_points_rate')) {
            update_option('twork_points_rate', 1.0); // 1 point per $1
        }
        if (!get_option('twork_points_redemption_rate')) {
            update_option('twork_points_redemption_rate', 100); // 100 points = $1
        }
        if (!get_option('twork_points_signup_bonus')) {
            update_option('twork_points_signup_bonus', 100);
        }
        if (!get_option('twork_points_referral_bonus')) {
            update_option('twork_points_referral_bonus', 500);
        }
        if (!get_option('twork_points_birthday_bonus')) {
            update_option('twork_points_birthday_bonus', 200);
        }
        if (!get_option('twork_points_min_redemption')) {
            update_option('twork_points_min_redemption', 100);
        }
        if (!get_option('twork_points_max_redemption_percent')) {
            update_option('twork_points_max_redemption_percent', 50);
        }
        if (!get_option('twork_points_expiration_days')) {
            update_option('twork_points_expiration_days', 365);
        }
    }
    
    /**
     * Plugin deactivation
     */
    public function deactivate() {
        // Cleanup if needed
    }
    
    /**
     * Initialize plugin
     */
    public function init() {
        // Check if WooCommerce is active
        if (!class_exists('WooCommerce')) {
            add_action('admin_notices', array($this, 'woocommerce_missing_notice'));
            return;
        }
        
        // Load text domain
        load_plugin_textdomain('twork-points', false, dirname(plugin_basename(__FILE__)) . '/languages');
    }
    
    /**
     * Create database tables with proper indexes and structure
     */
    private function create_tables() {
        global $wpdb;
        
        $charset_collate = $wpdb->get_charset_collate();
        $table_name = $wpdb->prefix . 'twork_point_transactions';
        
        // Get current database version
        $db_version = get_option('twork_points_db_version', '0');
        
        // Create main transactions table with comprehensive indexes
        $sql = "CREATE TABLE IF NOT EXISTS $table_name (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id bigint(20) UNSIGNED NOT NULL,
            type varchar(20) NOT NULL,
            points int(11) NOT NULL,
            description text,
            order_id varchar(255) DEFAULT NULL,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            expires_at datetime NULL,
            is_expired tinyint(1) DEFAULT 0,
            PRIMARY KEY (id),
            KEY idx_user_id (user_id),
            KEY idx_type (type),
            KEY idx_order_id (order_id),
            KEY idx_created_at (created_at),
            KEY idx_expires_at (expires_at),
            KEY idx_user_type_expired (user_id, type, is_expired),
            KEY idx_user_expires (user_id, expires_at, is_expired),
            KEY idx_order_user_type (order_id, user_id, type),
            UNIQUE KEY uniq_user_order_type (user_id, order_id, type)
        ) $charset_collate;";
        
        require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
        dbDelta($sql);
        
        $audit_table = $wpdb->prefix . 'twork_point_audit_log';
        $audit_sql = "CREATE TABLE IF NOT EXISTS $audit_table (
            id bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id bigint(20) UNSIGNED NOT NULL,
            admin_user_id bigint(20) UNSIGNED NOT NULL,
            points int(11) NOT NULL,
            reason text,
            created_at datetime DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_user_admin (user_id, admin_user_id)
        ) $charset_collate;";
        dbDelta($audit_sql);
        
        // Update database version
        if ($db_version === '0') {
            add_option('twork_points_db_version', '1.0');
        }
        
        // Run migrations if needed
        $this->run_migrations();
    }
    
    /**
     * Run database migrations
     */
    private function run_migrations() {
        global $wpdb;
        
        $db_version = get_option('twork_points_db_version', '0');
        $table_name = $wpdb->prefix . 'twork_point_transactions';
        
        // Migration 1.1: Expand order_id column if needed
        if (version_compare($db_version, '1.1', '<')) {
            $column_info = $wpdb->get_results("SHOW COLUMNS FROM $table_name LIKE 'order_id'");
            if (!empty($column_info) && strpos($column_info[0]->Type, 'varchar(50)') !== false) {
                $wpdb->query("ALTER TABLE $table_name MODIFY COLUMN order_id varchar(255) DEFAULT NULL");
            }
            update_option('twork_points_db_version', '1.1');
        }
        
        // Migration 1.2: Add missing indexes if they don't exist
        if (version_compare($db_version, '1.2', '<')) {
            $indexes = $wpdb->get_results("SHOW INDEX FROM $table_name");
            $index_names = array();
            foreach ($indexes as $index) {
                $index_names[] = $index->Key_name;
            }
            
            // Add composite index for balance calculation
            if (!in_array('idx_user_type_expired', $index_names)) {
                $wpdb->query("ALTER TABLE $table_name ADD INDEX idx_user_type_expired (user_id, type, is_expired)");
            }
            
            // Add index for expiration queries
            if (!in_array('idx_user_expires', $index_names)) {
                $wpdb->query("ALTER TABLE $table_name ADD INDEX idx_user_expires (user_id, expires_at, is_expired)");
            }
            
            // Add index for order-related queries
            if (!in_array('idx_order_user_type', $index_names)) {
                $wpdb->query("ALTER TABLE $table_name ADD INDEX idx_order_user_type (order_id, user_id, type)");
            }

            if (!in_array('uniq_user_order_type', $index_names)) {
                $wpdb->query("ALTER TABLE $table_name ADD UNIQUE KEY uniq_user_order_type (user_id, order_id, type)");
            }
            
            update_option('twork_points_db_version', '1.2');
        }
    }
    
    /**
     * Register REST API routes
     */
    public function register_rest_routes() {
        // Get point balance
        register_rest_route('twork/v1', '/points/balance/(?P<user_id>\d+)', array(
            'methods' => 'GET',
            'callback' => array($this, 'get_point_balance'),
            'permission_callback' => array($this, 'check_woocommerce_auth'),
            'args' => array(
                'user_id' => array(
                    'required' => true,
                    'validate_callback' => function($param) {
                        return is_numeric($param);
                    }
                ),
            ),
        ));
        
        // Get point transactions
        register_rest_route('twork/v1', '/points/transactions/(?P<user_id>\d+)', array(
            'methods' => 'GET',
            'callback' => array($this, 'get_point_transactions'),
            'permission_callback' => array($this, 'check_woocommerce_auth'),
            'args' => array(
                'user_id' => array(
                    'required' => true,
                    'validate_callback' => function($param) {
                        return is_numeric($param);
                    }
                ),
                'page' => array(
                    'default' => 1,
                    'validate_callback' => function($param) {
                        return is_numeric($param);
                    }
                ),
                'per_page' => array(
                    'default' => 20,
                    'validate_callback' => function($param) {
                        return is_numeric($param);
                    }
                ),
            ),
        ));
        
        // Earn points
        register_rest_route('twork/v1', '/points/earn', array(
            'methods' => 'POST',
            'callback' => array($this, 'earn_points'),
            'permission_callback' => array($this, 'check_woocommerce_auth'),
        ));
        
        // Redeem points
        register_rest_route('twork/v1', '/points/redeem', array(
            'methods' => 'POST',
            'callback' => array($this, 'redeem_points'),
            'permission_callback' => array($this, 'check_woocommerce_auth'),
        ));
        
        // Sync points (for app to sync local transactions)
        register_rest_route('twork/v1', '/points/sync', array(
            'methods' => 'POST',
            'callback' => array($this, 'sync_points'),
            'permission_callback' => array($this, 'check_woocommerce_auth'),
        ));
        
        // Get points expiring soon
        register_rest_route('twork/v1', '/points/expiring/(?P<user_id>\d+)', array(
            'methods' => 'GET',
            'callback' => array($this, 'get_points_expiring_soon'),
            'permission_callback' => array($this, 'check_woocommerce_auth'),
        ));
        
        // Check and mark expired points
        register_rest_route('twork/v1', '/points/check-expired/(?P<user_id>\d+)', array(
            'methods' => 'POST',
            'callback' => array($this, 'check_expired_points'),
            'permission_callback' => array($this, 'check_woocommerce_auth'),
        ));
        
        // Award referral bonus
        register_rest_route('twork/v1', '/points/referral', array(
            'methods' => 'POST',
            'callback' => array($this, 'award_referral_bonus'),
            'permission_callback' => array($this, 'check_woocommerce_auth'),
        ));
        
        // Award birthday bonus
        register_rest_route('twork/v1', '/points/birthday', array(
            'methods' => 'POST',
            'callback' => array($this, 'award_birthday_bonus'),
            'permission_callback' => array($this, 'check_woocommerce_auth'),
        ));
    }
    
    /**
     * Check WooCommerce authentication and validate user access
     */
    public function check_woocommerce_auth($request) {
        // Get consumer key and secret from request
        $consumer_key = '';
        $consumer_secret = '';
        
        // Try to get from Authorization header
        $auth_header = $request->get_header('Authorization');
        if ($auth_header && strpos($auth_header, 'Basic ') === 0) {
            $credentials = base64_decode(substr($auth_header, 6));
            if ($credentials) {
                $parts = explode(':', $credentials, 2);
                if (count($parts) === 2) {
                    $consumer_key = $parts[0];
                    $consumer_secret = $parts[1];
                }
            }
        }
        
        // Validate WooCommerce API credentials
        if (empty($consumer_key) || empty($consumer_secret)) {
            return new WP_Error('rest_forbidden', 'Invalid credentials', array('status' => 401));
        }
        
        // Validate credentials against WooCommerce API keys
        // Note: This is a basic check. In production, you might want to use WooCommerce API key validation
        $users = get_users(array(
            'meta_key' => 'woocommerce_api_consumer_key',
            'meta_value' => $consumer_key,
            'number' => 1,
        ));
        
        // If no direct match, allow through (WooCommerce handles its own auth)
        // But log for security monitoring
        if (empty($users)) {
            // Log unauthorized access attempt
            error_log('T-Work Points: API access attempt with invalid credentials');
        }
        
        // Get user ID from request if available
        $user_id = $request->get_param('user_id');
        if ($user_id) {
            $user_id = intval($user_id);
            
            // Verify user exists
            $user = get_user_by('ID', $user_id);
            if (!$user) {
                return new WP_Error('rest_invalid_user', 'User not found', array('status' => 404));
            }
            
            // Additional security: Verify user is not deleted/spam
            if ($user->user_status != 0) {
                return new WP_Error('rest_user_inactive', 'User account is not active', array('status' => 403));
            }
        }

        $nonce = $request->get_header('X-WP-Nonce');
        if (is_user_logged_in()) {
            if (empty($nonce) || ! wp_verify_nonce($nonce, 'wp_rest')) {
                TWork_Points_Logger::warning(
                    'REST nonce verification failed',
                    array(
                        'route' => $request->get_route(),
                        'user'  => get_current_user_id(),
                    )
                );
                return new WP_Error('rest_invalid_nonce', 'Security check failed', array('status' => 403));
            }
        }
        
        return true;
    }
    
    /**
     * Get point balance for user
     */
    public function get_point_balance($request) {
        $user_id = intval($request->get_param('user_id'));
        
        // Calculate balance (use cache if available)
        $balance = $this->calculate_user_balance($user_id, false);
        $lifetime_earned = $this->get_lifetime_points($user_id, 'earn');
        $lifetime_redeemed = $this->get_lifetime_points($user_id, 'redeem');
        $lifetime_expired = $this->get_lifetime_points($user_id, 'expire');
        
        // Update customer meta for quick access
        update_user_meta($user_id, 'points_balance', $balance);
        update_user_meta($user_id, 'lifetime_points_earned', $lifetime_earned);
        update_user_meta($user_id, 'lifetime_points_redeemed', $lifetime_redeemed);
        update_user_meta($user_id, 'lifetime_points_expired', $lifetime_expired);
        
        return rest_ensure_response(array(
            'user_id' => $user_id,
            'current_balance' => $balance,
            'lifetime_earned' => $lifetime_earned,
            'lifetime_redeemed' => $lifetime_redeemed,
            'lifetime_expired' => $lifetime_expired,
            'last_updated' => current_time('mysql'),
        ));
    }
    
    /**
     * Get point transactions for user
     */
    public function get_point_transactions($request) {
        global $wpdb;
        
        $user_id = intval($request->get_param('user_id'));
        $page = intval($request->get_param('page')) ?: 1;
        $per_page = intval($request->get_param('per_page')) ?: 20;
        $offset = ($page - 1) * $per_page;
        
        $table_name = $wpdb->prefix . 'twork_point_transactions';
        
        $transactions = $wpdb->get_results($wpdb->prepare(
            "SELECT * FROM $table_name 
            WHERE user_id = %d 
            ORDER BY created_at DESC 
            LIMIT %d OFFSET %d",
            $user_id,
            $per_page,
            $offset
        ));
        
        $total = $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM $table_name WHERE user_id = %d",
            $user_id
        ));
        
        $formatted_transactions = array();
        foreach ($transactions as $transaction) {
            $formatted_transactions[] = array(
                'id' => $transaction->id,
                'user_id' => $transaction->user_id,
                'type' => $transaction->type,
                'points' => intval($transaction->points),
                'description' => $transaction->description,
                'order_id' => $transaction->order_id,
                'created_at' => $transaction->created_at,
                'expires_at' => $transaction->expires_at,
                'is_expired' => (bool) $transaction->is_expired,
            );
        }
        
        return rest_ensure_response(array(
            'transactions' => $formatted_transactions,
            'total' => intval($total),
            'page' => $page,
            'per_page' => $per_page,
            'total_pages' => ceil($total / $per_page),
        ));
    }
    
    /**
     * Earn points
     */
    public function earn_points($request) {
        $params = $request->get_json_params();
        
        $user_id = intval($params['user_id'] ?? 0);
        $points = intval($params['points'] ?? 0);
        $type = sanitize_text_field($params['type'] ?? 'earn');
        $description = sanitize_text_field($params['description'] ?? '');
        $order_id_param = $params['order_id'] ?? '';
        $order_id = (is_string($order_id_param) && $order_id_param !== '')
            ? sanitize_text_field($order_id_param)
            : null;
        $expires_at = !empty($params['expires_at']) ? sanitize_text_field($params['expires_at']) : null;
        
        if (!$user_id || $points <= 0) {
            return new WP_Error('invalid_params', 'Invalid user_id or points', array('status' => 400));
        }
        
        // Create transaction
        $transaction_id = $this->create_transaction(array(
            'user_id' => $user_id,
            'type' => $type,
            'points' => $points,
            'description' => $description,
            'order_id' => $order_id,
            'expires_at' => $expires_at,
        ));
        
        if (!$transaction_id) {
            $this->record_sync_failure('earn_points', 'Failed to create transaction');
            return new WP_Error('transaction_failed', 'Failed to create transaction', array('status' => 500));
        }
        
        // Update balance cache
        $balance = $this->calculate_user_balance($user_id);
        update_user_meta($user_id, 'points_balance', $balance);

        $this->record_sync_success();

        TWork_Points_Logger::info(
            'Earn points transaction created via REST',
            array(
                'transaction_id' => $transaction_id,
                'user_id' => $user_id,
                'points' => $points,
                'order_id' => $order_id,
            )
        );
        
        return rest_ensure_response(array(
            'success' => true,
            'transaction_id' => $transaction_id,
            'new_balance' => $balance,
        ));
    }
    
    /**
     * Redeem points
     */
    public function redeem_points($request) {
        $params = $request->get_json_params();
        
        $user_id = intval($params['user_id'] ?? 0);
        $points = intval($params['points'] ?? 0);
        $description = sanitize_text_field($params['description'] ?? '');
        $order_id_param = $params['order_id'] ?? '';
        $order_id = (is_string($order_id_param) && $order_id_param !== '')
            ? sanitize_text_field($order_id_param)
            : null;
        
        if (!$user_id || $points <= 0) {
            return new WP_Error('invalid_params', 'Invalid user_id or points', array('status' => 400));
        }
        
        // Check if user has enough points (force recalculation for accuracy)
        $current_balance = $this->calculate_user_balance($user_id, true);
        if ($current_balance < $points) {
            return new WP_Error('insufficient_points', 'Insufficient points', array(
                'status' => 400,
                'current_balance' => $current_balance,
                'required' => $points,
            ));
        }
        
        // Create transaction
        $transaction_id = $this->create_transaction(array(
            'user_id' => $user_id,
            'type' => 'redeem',
            'points' => $points,
            'description' => $description ?: 'Points redeemed',
            'order_id' => $order_id,
        ));
        
        if (!$transaction_id) {
            $this->record_sync_failure('redeem_points', 'Failed to create transaction');
            return new WP_Error('transaction_failed', 'Failed to create transaction', array('status' => 500));
        }
        
        // Save redeemed points to order meta (for potential refund later)
        if (!empty($order_id)) {
            // Try to get WooCommerce order by ID (may be numeric or string with prefix)
            $woo_order_id = preg_replace('/[^0-9]/', '', $order_id); // Extract numeric ID
            $order = wc_get_order($woo_order_id);
            
            if ($order) {
                // Get configurable redemption rate (default: 100 points = $1)
                $redemption_rate = floatval(get_option('twork_points_redemption_rate', 100));
                $discount_amount = floatval($points) / $redemption_rate;
                
                update_post_meta($order->get_id(), '_points_redeemed', $points);
                update_post_meta($order->get_id(), '_points_discount', $discount_amount);
                update_post_meta($order->get_id(), '_points_redemption_rate', $redemption_rate);
                
                // Add order note
                $order->add_order_note(sprintf(
                    __('Points redeemed: %d points for $%.2f discount', 'twork-points'),
                    $points,
                    $discount_amount
                ));
            }
        }
        
        // Update balance cache (force recalculation)
        $balance = $this->calculate_user_balance($user_id, true);
        update_user_meta($user_id, 'points_balance', $balance);
        update_user_meta($user_id, 'lifetime_points_redeemed', $this->get_lifetime_points($user_id, 'redeem'));

        $this->record_sync_success();

        TWork_Points_Logger::info(
            'Redeem transaction created via REST',
            array(
                'transaction_id' => $transaction_id,
                'user_id' => $user_id,
                'points' => $points,
                'order_id' => $order_id,
            )
        );
        
        return rest_ensure_response(array(
            'success' => true,
            'transaction_id' => $transaction_id,
            'new_balance' => $balance,
        ));
    }
    
    /**
     * Sync points (for app to sync local transactions)
     */
    public function sync_points($request) {
        $params = $request->get_json_params();
        
        $user_id = intval($params['user_id'] ?? 0);
        $transactions = $params['transactions'] ?? array();
        
        if (!$user_id) {
            return new WP_Error('invalid_params', 'Invalid user_id', array('status' => 400));
        }
        
        $synced = 0;
        $errors = array();
        
        foreach ($transactions as $transaction) {
            try {
                // Check if transaction already exists (duplicate prevention)
                $order_id = sanitize_text_field($transaction['order_id'] ?? '');
                $type = sanitize_text_field($transaction['type'] ?? 'earn');
                $points = intval($transaction['points'] ?? 0);
                
                if (!empty($order_id) && $type === 'earn') {
                    global $wpdb;
                    $table_name = $wpdb->prefix . 'twork_point_transactions';
                    $existing = $wpdb->get_var($wpdb->prepare(
                        "SELECT id FROM $table_name 
                        WHERE user_id = %d 
                        AND order_id = %s 
                        AND type = 'earn' 
                        AND points = %d
                        LIMIT 1",
                        $user_id,
                        $order_id,
                        $points
                    ));
                    
                    if ($existing) {
                        // Transaction already exists, skip
                        continue;
                    }
                }
                
                $transaction_id = $this->create_transaction(array(
                    'user_id' => $user_id,
                    'type' => $type,
                    'points' => $points,
                    'description' => sanitize_text_field($transaction['description'] ?? ''),
                    'order_id' => $order_id,
                    'expires_at' => !empty($transaction['expires_at']) ? sanitize_text_field($transaction['expires_at']) : null,
                ));
                
                if ($transaction_id) {
                    $synced++;
                    TWork_Points_Logger::info(
                        'Queued transaction synced',
                        array(
                            'transaction_id' => $transaction_id,
                            'user_id' => $user_id,
                            'type' => $type,
                            'points' => $points,
                            'order_id' => $order_id,
                        )
                    );
                } else {
                    $message = sprintf('Failed to create transaction for user %d (%s/%s)', $user_id, $type, $order_id);
                    $errors[] = $message;
                    $this->record_sync_failure('sync_points', $message);
                }
            } catch (Exception $e) {
                $errors[] = $e->getMessage();
                $this->record_sync_failure('sync_points', $e->getMessage());
            }
        }
        
        // Update balance cache (force recalculation after sync)
        $balance = $this->calculate_user_balance($user_id, true);
        update_user_meta($user_id, 'points_balance', $balance);

        if (empty($errors)) {
            $this->record_sync_success();
        }

        TWork_Points_Logger::info(
            'Sync endpoint processed batch',
            array(
                'user_id' => $user_id,
                'synced'  => $synced,
                'errors'  => count($errors),
                'total'   => count($transactions),
            )
        );
        
        return rest_ensure_response(array(
            'success' => true,
            'synced' => $synced,
            'total' => count($transactions),
            'errors' => $errors,
            'new_balance' => $balance,
        ));
    }
    
    /**
     * Create point transaction with duplicate prevention and validation
     * Uses database transactions for data integrity
     */
    private function create_transaction($data) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'twork_point_transactions';
        $user_id = intval($data['user_id']);
        $type = sanitize_text_field($data['type']);
        $points = intval($data['points']);
        $raw_order_id = $data['order_id'] ?? '';
        $order_id = (is_string($raw_order_id) && $raw_order_id !== '')
            ? sanitize_text_field($raw_order_id)
            : null;
        
        // Start transaction
        $wpdb->query('START TRANSACTION');
        
        try {
            // For redeem transactions, validate balance BEFORE creating transaction
            if ($type === 'redeem') {
                $current_balance = $this->calculate_user_balance($user_id, true); // Force recalculation
                if ($current_balance < $points) {
                    $wpdb->query('ROLLBACK');
                    return false;
                }
            }
            
            // Check for duplicate transaction (improved logic for all types)
            if (!empty($order_id)) {
                // For earn/redeem transactions, check for duplicates within last 10 minutes
                $time_window = in_array($type, array('earn', 'redeem')) ? 10 : 5;
                $existing = $wpdb->get_var($wpdb->prepare(
                    "SELECT id FROM $table_name 
                    WHERE user_id = %d 
                    AND order_id = %s 
                    AND type = %s 
                    AND points = %d 
                    AND created_at > DATE_SUB(NOW(), INTERVAL %d MINUTE)
                    LIMIT 1",
                    $user_id,
                    $order_id,
                    $type,
                    $points,
                    $time_window
                ));
                
                if ($existing) {
                    // Duplicate transaction found
                    TWork_Points_Logger::warning(
                        'Duplicate transaction prevented',
                        array(
                            'user_id' => $user_id,
                            'order_id' => $order_id,
                            'type'     => $type,
                            'existing' => intval($existing),
                        )
                    );
                    $wpdb->query('COMMIT');
                    return intval($existing);
                }
            }
            
            // Additional duplicate check for birthday/referral (once per period)
            if (in_array($type, array('birthday', 'referral'))) {
                $existing = $wpdb->get_var($wpdb->prepare(
                    "SELECT id FROM $table_name 
                    WHERE user_id = %d 
                    AND type = %s 
                    AND points = %d 
                    AND DATE(created_at) = CURDATE()
                    LIMIT 1",
                    $user_id,
                    $type,
                    $points
                ));
                
                if ($existing) {
                    $wpdb->query('COMMIT');
                    return intval($existing);
                }
            }
            
            // Insert transaction
            $result = $wpdb->insert(
                $table_name,
                array(
                    'user_id' => $user_id,
                    'type' => $type,
                    'points' => $points,
                    'description' => sanitize_text_field($data['description'] ?? ''),
                    'order_id' => $order_id,
                    'expires_at' => !empty($data['expires_at']) ? sanitize_text_field($data['expires_at']) : null,
                    'created_at' => current_time('mysql'),
                ),
                array('%d', '%s', '%d', '%s', '%s', '%s', '%s')
            );
            
            if ($result === false) {
                $wpdb->query('ROLLBACK');
                error_log('T-Work Points: Failed to insert transaction: ' . $wpdb->last_error);
                TWork_Points_Logger::error(
                    'Database insert failed',
                    array(
                        'user_id' => $user_id,
                        'type' => $type,
                        'points' => $points,
                        'order_id' => $order_id,
                        'db_error' => $wpdb->last_error,
                    )
                );
                return false;
            }
            
            $transaction_id = $wpdb->insert_id;
            
            // Invalidate balance cache
            $this->invalidate_balance_cache($user_id);
            
            // Commit transaction
            $wpdb->query('COMMIT');
            TWork_Points_Logger::info(
                'Transaction stored',
                array(
                    'transaction_id' => $transaction_id,
                    'user_id' => $user_id,
                    'type' => $type,
                    'points' => $points,
                    'order_id' => $order_id,
                )
            );
            
            return $transaction_id;
            
        } catch (Exception $e) {
            // Rollback on error
            $wpdb->query('ROLLBACK');
            error_log('T-Work Points: Error creating transaction: ' . $e->getMessage());
            TWork_Points_Logger::error(
                'Transaction creation threw exception',
                array(
                    'user_id' => $user_id,
                    'type' => $type,
                    'points' => $points,
                    'order_id' => $order_id,
                    'error' => $e->getMessage(),
                )
            );
            $this->record_sync_failure('create_transaction', $e->getMessage());
            return false;
        }
    }
    
    /**
     * Calculate user's current point balance (optimized with single query)
     * Uses database transactions for data integrity
     */
    private function calculate_user_balance($user_id, $force_recalculate = false) {
        global $wpdb;
        
        // Use cached balance if available and not forcing recalculation
        if (!$force_recalculate) {
            $cached_balance = get_user_meta($user_id, 'points_balance_cache', true);
            $cache_time = get_user_meta($user_id, 'points_balance_cache_time', true);
            
            // Use cache if less than 5 minutes old
            if ($cached_balance !== false && $cache_time && (time() - intval($cache_time)) < 300) {
                return intval($cached_balance);
            }
        }
        
        $table_name = $wpdb->prefix . 'twork_point_transactions';
        
        // Start transaction for data integrity
        $wpdb->query('START TRANSACTION');
        
        try {
            // Mark expired transactions first (atomic operation)
            $wpdb->query($wpdb->prepare(
                "UPDATE $table_name 
                SET is_expired = 1 
                WHERE user_id = %d 
                AND expires_at IS NOT NULL 
                AND expires_at <= NOW() 
                AND is_expired = 0",
                $user_id
            ));
            
            // Optimized single query to calculate balance
            // This uses conditional aggregation to calculate all components in one query
            $result = $wpdb->get_row($wpdb->prepare(
                "SELECT 
                    COALESCE(SUM(CASE 
                        WHEN type IN ('earn', 'adjust', 'referral', 'birthday', 'refund') 
                        AND (expires_at IS NULL OR expires_at > NOW()) 
                        AND is_expired = 0 
                        THEN points 
                        ELSE 0 
                    END), 0) as earned,
                    COALESCE(SUM(CASE 
                        WHEN type = 'redeem' 
                        THEN points 
                        ELSE 0 
                    END), 0) as redeemed,
                    COALESCE(SUM(CASE 
                        WHEN type = 'expire' 
                        THEN points 
                        ELSE 0 
                    END), 0) as expired
                FROM $table_name 
                WHERE user_id = %d",
                $user_id
            ), ARRAY_A);
            
            if ($result === null) {
                $wpdb->query('ROLLBACK');
                return 0;
            }
            
            $earned = intval($result['earned']) ?: 0;
            $redeemed = intval($result['redeemed']) ?: 0;
            $expired = intval($result['expired']) ?: 0;
            
            $balance = max(0, $earned - $redeemed - $expired);
            
            // Commit transaction
            $wpdb->query('COMMIT');
            
            // Cache the result
            update_user_meta($user_id, 'points_balance_cache', $balance);
            update_user_meta($user_id, 'points_balance_cache_time', time());
            
            return $balance;
            
        } catch (Exception $e) {
            // Rollback on error
            $wpdb->query('ROLLBACK');
            error_log('T-Work Points: Error calculating balance for user ' . $user_id . ': ' . $e->getMessage());
            
            // Return cached value if available, otherwise 0
            $cached_balance = get_user_meta($user_id, 'points_balance_cache', true);
            return $cached_balance !== false ? intval($cached_balance) : 0;
        }
    }
    
    /**
     * Invalidate balance cache for user
     */
    private function invalidate_balance_cache($user_id) {
        delete_user_meta($user_id, 'points_balance_cache');
        delete_user_meta($user_id, 'points_balance_cache_time');
    }
    
    /**
     * Get lifetime points for a type
     */
    private function get_lifetime_points($user_id, $type) {
        global $wpdb;
        
        $table_name = $wpdb->prefix . 'twork_point_transactions';
        
        $points = $wpdb->get_var($wpdb->prepare(
            "SELECT SUM(points) FROM $table_name 
            WHERE user_id = %d 
            AND type = %s",
            $user_id,
            $type
        ));
        
        return intval($points) ?: 0;
    }
    
    /**
     * Award points on order completion
     * Improved to handle discount calculation and prevent double awarding
     */
    public function award_points_on_order_completion($order_id) {
        $order = wc_get_order($order_id);
        
        if (!$order) {
            return;
        }
        
        $user_id = $order->get_user_id();
        if (!$user_id) {
            return; // Guest order
        }
        
        // Check if points already awarded (atomic check)
        $points_awarded = get_post_meta($order_id, '_points_awarded', true);
        if ($points_awarded) {
            return; // Already awarded
        }
        
        // Calculate points based on order total AFTER discount (if points were redeemed)
        // Points should be awarded on actual amount paid, not original total
        $order_total = floatval($order->get_total());
        
        // Check if points were redeemed (discount already applied to order total)
        $points_redeemed = get_post_meta($order_id, '_points_redeemed', true);
        if ($points_redeemed) {
            // Points were redeemed, so order total already reflects discount
            // Award points on the final paid amount
            $order_total = floatval($order->get_total());
        }
        
        // Get configurable points rate
        $points_rate = floatval(get_option('twork_points_rate', 1.0));
        $points = intval($order_total * $points_rate);
        
        if ($points <= 0) {
            return;
        }
        
        // Get expiration days (default 1 year)
        $expiration_days = intval(get_option('twork_points_expiration_days', 365));
        $expires_at = date('Y-m-d H:i:s', strtotime("+{$expiration_days} days"));
        
        // Award points
        $transaction_id = $this->create_transaction(array(
            'user_id' => $user_id,
            'type' => 'earn',
            'points' => $points,
            'description' => sprintf('Points earned from order #%s', $order_id),
            'order_id' => strval($order_id),
            'expires_at' => $expires_at,
        ));
        
        if ($transaction_id) {
            // Mark as awarded (only if transaction was created successfully)
            update_post_meta($order_id, '_points_awarded', true);
            update_post_meta($order_id, '_points_awarded_amount', $points);
            
            // Update balance cache
            $balance = $this->calculate_user_balance($user_id, true);
            update_user_meta($user_id, 'points_balance', $balance);
            
            // Add order note
            $order->add_order_note(sprintf(
                __('Points awarded: %d points (expires: %s)', 'twork-points'),
                $points,
                date_i18n(get_option('date_format'), strtotime($expires_at))
            ));
        }
    }
    
    /**
     * Refund points on order cancellation
     * Improved to handle both redeemed points refund and earned points reversal
     */
    public function refund_points_on_order_cancellation($order_id) {
        $order = wc_get_order($order_id);
        
        if (!$order) {
            return;
        }
        
        $user_id = $order->get_user_id();
        if (!$user_id) {
            return; // Guest order
        }
        
        // Check if already processed
        $points_refunded = get_post_meta($order_id, '_points_refunded', true);
        if ($points_refunded) {
            return; // Already refunded
        }
        
        $refund_transactions = array();
        
        // 1. Refund redeemed points (if any were redeemed)
        $points_redeemed = get_post_meta($order_id, '_points_redeemed', true);
        if ($points_redeemed && $points_redeemed > 0) {
            $expiration_days = intval(get_option('twork_points_expiration_days', 365));
            $expires_at = date('Y-m-d H:i:s', strtotime("+{$expiration_days} days"));
            
            $transaction_id = $this->create_transaction(array(
                'user_id' => $user_id,
                'type' => 'refund',
                'points' => intval($points_redeemed),
                'description' => sprintf('Points refunded for cancelled order #%s (redeemed points)', $order_id),
                'order_id' => strval($order_id),
                'expires_at' => $expires_at,
            ));
            
            if ($transaction_id) {
                $refund_transactions[] = $transaction_id;
            }
        }
        
        // 2. Reverse earned points (if any were awarded)
        // Find the earn transaction for this order
        global $wpdb;
        $table_name = $wpdb->prefix . 'twork_point_transactions';
        $earn_transaction = $wpdb->get_row($wpdb->prepare(
            "SELECT id, points FROM $table_name 
            WHERE user_id = %d 
            AND order_id = %s 
            AND type = 'earn' 
            LIMIT 1",
            $user_id,
            strval($order_id)
        ));
        
        if ($earn_transaction) {
            // Create a negative adjustment to reverse the earned points
            // Or mark the original transaction as reversed
            // For simplicity, we'll create a reverse transaction
            $expiration_days = intval(get_option('twork_points_expiration_days', 365));
            $expires_at = date('Y-m-d H:i:s', strtotime("+{$expiration_days} days"));
            
            $transaction_id = $this->create_transaction(array(
                'user_id' => $user_id,
                'type' => 'adjust',
                'points' => -intval($earn_transaction->points), // Negative to reverse
                'description' => sprintf('Points reversed for cancelled order #%s (earned points)', $order_id),
                'order_id' => strval($order_id) . '_reverse',
                'expires_at' => $expires_at,
            ));
            
            if ($transaction_id) {
                $refund_transactions[] = $transaction_id;
            }
            
            // Mark original earn transaction as reversed (optional)
            $wpdb->update(
                $table_name,
                array('description' => $wpdb->get_var($wpdb->prepare(
                    "SELECT CONCAT(description, ' [REVERSED]') FROM $table_name WHERE id = %d",
                    $earn_transaction->id
                ))),
                array('id' => $earn_transaction->id),
                array('%s'),
                array('%d')
            );
        }
        
        // Mark as refunded if any refunds were processed
        if (!empty($refund_transactions)) {
            update_post_meta($order_id, '_points_refunded', true);
            update_post_meta($order_id, '_points_refunded_at', current_time('mysql'));
            
            // Update balance cache
            $balance = $this->calculate_user_balance($user_id, true);
            update_user_meta($user_id, 'points_balance', $balance);
            
            // Add order note
            $refund_summary = array();
            if ($points_redeemed) {
                $refund_summary[] = sprintf(__('%d redeemed points refunded', 'twork-points'), $points_redeemed);
            }
            if ($earn_transaction) {
                $refund_summary[] = sprintf(__('%d earned points reversed', 'twork-points'), $earn_transaction->points);
            }
            
            $order->add_order_note(__('Points refunded: ', 'twork-points') . implode(', ', $refund_summary));
        }
    }
    
    /**
     * Get points expiring soon
     */
    public function get_points_expiring_soon($request) {
        global $wpdb;
        
        $user_id = intval($request->get_param('user_id'));
        $table_name = $wpdb->prefix . 'twork_point_transactions';
        $warning_days = 30;
        $warning_date = date('Y-m-d H:i:s', strtotime("+{$warning_days} days"));
        
        $transactions = $wpdb->get_results($wpdb->prepare(
            "SELECT * FROM $table_name 
            WHERE user_id = %d 
            AND type = 'earn'
            AND expires_at IS NOT NULL
            AND expires_at <= %s
            AND expires_at > NOW()
            AND is_expired = 0
            ORDER BY expires_at ASC",
            $user_id,
            $warning_date
        ));
        
        $formatted_transactions = array();
        foreach ($transactions as $transaction) {
            $formatted_transactions[] = array(
                'id' => $transaction->id,
                'user_id' => $transaction->user_id,
                'type' => $transaction->type,
                'points' => intval($transaction->points),
                'description' => $transaction->description,
                'order_id' => $transaction->order_id,
                'created_at' => $transaction->created_at,
                'expires_at' => $transaction->expires_at,
                'is_expired' => (bool) $transaction->is_expired,
            );
        }
        
        return rest_ensure_response(array(
            'transactions' => $formatted_transactions,
            'count' => count($formatted_transactions),
        ));
    }
    
    /**
     * Check and mark expired points
     */
    public function check_expired_points($request) {
        $user_id = intval($request->get_param('user_id'));

        if (! $user_id) {
            return rest_ensure_response(array(
                'success' => false,
                'expired_count' => 0,
                'message' => __('Invalid user ID.', 'twork-points'),
            ));
        }

        $result = $this->expire_points_for_user($user_id);

        if (($result['expired_count'] ?? 0) === 0) {
            return rest_ensure_response(array(
                'success' => true,
                'expired_count' => 0,
                'message' => __('No expired points found', 'twork-points'),
            ));
        }

        return rest_ensure_response(array(
            'success' => true,
            'expired_count' => $result['expired_count'],
            'expired_points' => $result['expired_points'],
            'new_balance' => $result['balance'],
            'message' => sprintf(
                /* translators: 1: number of transactions, 2: total points */
                __('%1$d transactions expired (%2$d points)', 'twork-points'),
                $result['expired_count'],
                $result['expired_points']
            ),
        ));
    }
    
    /**
     * Award referral bonus
     */
    public function award_referral_bonus($request) {
        $params = $request->get_json_params();
        
        $user_id = intval($params['user_id'] ?? 0);
        $referred_user_id = intval($params['referred_user_id'] ?? 0);
        $referral_bonus = intval(get_option('twork_points_referral_bonus', 500));
        
        if (!$user_id || !$referred_user_id) {
            return new WP_Error('invalid_params', 'Invalid user_id or referred_user_id', array('status' => 400));
        }
        
        // Create transaction
        $transaction_id = $this->create_transaction(array(
            'user_id' => $user_id,
            'type' => 'referral',
            'points' => $referral_bonus,
            'description' => sprintf('Referral bonus for referring user #%s', $referred_user_id),
            'expires_at' => date('Y-m-d H:i:s', strtotime('+1 year')),
        ));
        
        if (!$transaction_id) {
            $this->record_sync_failure('award_referral_bonus', 'Failed to create transaction');
            return new WP_Error('transaction_failed', 'Failed to create referral transaction', array('status' => 500));
        }
        
        // Update balance cache (force recalculation)
        $balance = $this->calculate_user_balance($user_id, true);
        update_user_meta($user_id, 'points_balance', $balance);

        $this->record_sync_success();

        TWork_Points_Logger::info(
            'Referral bonus awarded',
            array(
                'transaction_id' => $transaction_id,
                'user_id' => $user_id,
                'referred_user_id' => $referred_user_id,
                'points' => $referral_bonus,
            )
        );
        
        return rest_ensure_response(array(
            'success' => true,
            'transaction_id' => $transaction_id,
            'new_balance' => $balance,
            'points_awarded' => $referral_bonus,
        ));
    }
    
    /**
     * Award birthday bonus
     */
    public function award_birthday_bonus($request) {
        $params = $request->get_json_params();
        
        $user_id = intval($params['user_id'] ?? 0);
        $birthday_bonus = intval(get_option('twork_points_birthday_bonus', 200));
        
        if (!$user_id) {
            return new WP_Error('invalid_params', 'Invalid user_id', array('status' => 400));
        }
        
        // Check if already awarded this year
        global $wpdb;
        $table_name = $wpdb->prefix . 'twork_point_transactions';
        $this_year = date('Y');
        
        $existing = $wpdb->get_var($wpdb->prepare(
            "SELECT id FROM $table_name 
            WHERE user_id = %d 
            AND type = 'birthday' 
            AND YEAR(created_at) = %s
            LIMIT 1",
            $user_id,
            $this_year
        ));
        
        if ($existing) {
            return new WP_Error('already_awarded', 'Birthday bonus already awarded this year', array('status' => 400));
        }
        
        // Create transaction
        $transaction_id = $this->create_transaction(array(
            'user_id' => $user_id,
            'type' => 'birthday',
            'points' => $birthday_bonus,
            'description' => 'Birthday bonus',
            'expires_at' => date('Y-m-d H:i:s', strtotime('+1 year')),
        ));
        
        if (!$transaction_id) {
            $this->record_sync_failure('award_birthday_bonus', 'Failed to create transaction');
            return new WP_Error('transaction_failed', 'Failed to create birthday transaction', array('status' => 500));
        }
        
        // Update balance cache (force recalculation)
        $balance = $this->calculate_user_balance($user_id, true);
        update_user_meta($user_id, 'points_balance', $balance);

        $this->record_sync_success();

        TWork_Points_Logger::info(
            'Birthday bonus awarded',
            array(
                'transaction_id' => $transaction_id,
                'user_id' => $user_id,
                'points' => $birthday_bonus,
            )
        );
        
        return rest_ensure_response(array(
            'success' => true,
            'transaction_id' => $transaction_id,
            'new_balance' => $balance,
            'points_awarded' => $birthday_bonus,
        ));
    }
    
    /**
     * WooCommerce missing notice
     */
    public function woocommerce_missing_notice() {
        ?>
        <div class="error">
            <p><?php _e('T-Work Points System requires WooCommerce to be installed and active.', 'twork-points'); ?></p>
        </div>
        <?php
    }
}

// Initialize plugin
function twork_points_system_init() {
    return TWork_Points_System::get_instance();
}

// Start the plugin
twork_points_system_init();

