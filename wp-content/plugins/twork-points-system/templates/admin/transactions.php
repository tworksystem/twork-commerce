<?php
/**
 * Transactions Admin Template
 *
 * @package TWorkPoints
 */

if (! defined('ABSPATH')) {
    exit;
}

$types = array(
    '' => __('All types', 'twork-points'),
    'earn' => __('Earn', 'twork-points'),
    'redeem' => __('Redeem', 'twork-points'),
    'adjust' => __('Adjust', 'twork-points'),
    'expire' => __('Expire', 'twork-points'),
    'referral' => __('Referral', 'twork-points'),
    'birthday' => __('Birthday', 'twork-points'),
    'refund' => __('Refund', 'twork-points'),
);
?>
<div class="wrap twork-points-admin">
    <h1><?php esc_html_e('Point Transactions', 'twork-points'); ?></h1>

    <form method="get" class="twork-filter-form">
        <input type="hidden" name="page" value="twork-points-transactions" />
        <input type="hidden" name="paged" value="1" />

        <select name="type">
            <?php foreach ($types as $value => $label) : ?>
                <option value="<?php echo esc_attr($value); ?>" <?php selected($args['type'], $value); ?>><?php echo esc_html($label); ?></option>
            <?php endforeach; ?>
        </select>

        <input type="number" name="user_id" placeholder="<?php esc_attr_e('User ID', 'twork-points'); ?>" value="<?php echo esc_attr($args['user_id']); ?>" />
        <input type="text" name="order_id" placeholder="<?php esc_attr_e('Order ID', 'twork-points'); ?>" value="<?php echo esc_attr($args['order_id']); ?>" />
        <input type="search" name="search" placeholder="<?php esc_attr_e('Search description or order…', 'twork-points'); ?>" value="<?php echo esc_attr($args['search']); ?>" />

        <?php
        $current_per_page = isset($per_page) ? intval($per_page) : 25;
        ?>
        <select name="per_page">
            <?php foreach (array(25, 50, 100, 200) as $option) : ?>
                <option value="<?php echo esc_attr($option); ?>" <?php selected($current_per_page, $option); ?>><?php echo esc_html(sprintf(_n('%d row per page', '%d rows per page', $option, 'twork-points'), $option)); ?></option>
            <?php endforeach; ?>
        </select>

        <?php submit_button(__('Filter', 'twork-points'), 'secondary', '', false); ?>
        <a class="button button-secondary" href="<?php echo esc_url(admin_url('admin.php?page=twork-points-transactions')); ?>"><?php esc_html_e('Reset', 'twork-points'); ?></a>
    </form>

    <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" class="twork-export-form">
        <?php wp_nonce_field('twork_points_export'); ?>
        <input type="hidden" name="action" value="twork_points_export" />
        <input type="hidden" name="type" value="<?php echo esc_attr($args['type']); ?>" />
        <input type="hidden" name="user_id" value="<?php echo esc_attr($args['user_id']); ?>" />
        <input type="hidden" name="order_id" value="<?php echo esc_attr($args['order_id']); ?>" />
        <input type="hidden" name="search" value="<?php echo esc_attr($args['search']); ?>" />
        <?php submit_button(__('Export CSV (filters applied)', 'twork-points'), 'secondary', 'submit', false); ?>
    </form>

    <table class="widefat fixed striped">
        <thead>
            <tr>
                <th><?php esc_html_e('ID', 'twork-points'); ?></th>
                <th><?php esc_html_e('Date', 'twork-points'); ?></th>
                <th><?php esc_html_e('User', 'twork-points'); ?></th>
                <th><?php esc_html_e('Type', 'twork-points'); ?></th>
                <th><?php esc_html_e('Points', 'twork-points'); ?></th>
                <th><?php esc_html_e('Order', 'twork-points'); ?></th>
                <th><?php esc_html_e('Expires', 'twork-points'); ?></th>
                <th><?php esc_html_e('Expired?', 'twork-points'); ?></th>
                <th><?php esc_html_e('Description', 'twork-points'); ?></th>
            </tr>
        </thead>
        <tbody>
            <?php if (! empty($transactions)) : ?>
                <?php foreach ($transactions as $transaction) :
                    $user = get_user_by('ID', $transaction['user_id']);
                    ?>
                    <tr>
                        <td><?php echo esc_html($transaction['id']); ?></td>
                        <td><?php echo esc_html(date_i18n(get_option('date_format') . ' ' . get_option('time_format'), strtotime($transaction['created_at']))); ?></td>
                        <td>
                            <?php if ($user) : ?>
                                <a href="<?php echo esc_url(add_query_arg(array('page' => 'twork-points-users', 'user_id' => $user->ID), admin_url('admin.php'))); ?>"><?php echo esc_html($user->display_name); ?></a>
                            <?php else : ?>
                                <?php esc_html_e('Unknown user', 'twork-points'); ?>
                            <?php endif; ?>
                        </td>
                        <td><span class="twork-type-badge twork-type-<?php echo esc_attr($transaction['type']); ?>"><?php echo esc_html(ucfirst($transaction['type'])); ?></span></td>
                        <td><?php echo esc_html(number_format_i18n($transaction['points'])); ?></td>
                        <td>
                            <?php if (! empty($transaction['order_id'])) : ?>
                                <a href="<?php echo esc_url(admin_url('post.php?post=' . absint($transaction['order_id']) . '&action=edit')); ?>">#<?php echo esc_html($transaction['order_id']); ?></a>
                            <?php else : ?>
                                &mdash;
                            <?php endif; ?>
                        </td>
                        <td>
                            <?php echo $transaction['expires_at'] ? esc_html(date_i18n(get_option('date_format'), strtotime($transaction['expires_at']))) : '&mdash;'; ?>
                        </td>
                        <td><?php echo $transaction['is_expired'] ? esc_html__('Yes', 'twork-points') : esc_html__('No', 'twork-points'); ?></td>
                        <td><?php echo esc_html($transaction['description']); ?></td>
                    </tr>
                <?php endforeach; ?>
            <?php else : ?>
                <tr>
                    <td colspan="9"><?php esc_html_e('No transactions match your filters.', 'twork-points'); ?></td>
                </tr>
            <?php endif; ?>
        </tbody>
    </table>

    <?php if (! empty($pagination_links)) : ?>
        <div class="twork-pagination">
            <div class="tablenav-pages"><?php echo wp_kses_post($pagination_links); ?></div>
        </div>
    <?php endif; ?>
</div>
