<?php
/**
 * User Points Management Template
 *
 * @package TWorkPoints
 */

if (! defined('ABSPATH')) {
    exit;
}
?>
<div class="wrap twork-points-admin">
    <h1><?php esc_html_e('User Points Management', 'twork-points'); ?></h1>

    <form method="get" class="twork-user-search-form">
        <input type="hidden" name="page" value="twork-points-users" />
        <label class="screen-reader-text" for="twork-user-search"><?php esc_html_e('Search users', 'twork-points'); ?></label>
        <input type="search" id="twork-user-search" name="s" value="<?php echo esc_attr($search_query); ?>" placeholder="<?php esc_attr_e('Search by name or email…', 'twork-points'); ?>" />
        <?php submit_button(__('Search Users', 'twork-points'), 'secondary', '', false); ?>
    </form>

    <div class="twork-user-columns">
        <div class="twork-user-column">
            <h2><?php esc_html_e('Matching Users', 'twork-points'); ?></h2>
            <table class="widefat fixed striped">
                <thead>
                    <tr>
                        <th><?php esc_html_e('User', 'twork-points'); ?></th>
                        <th><?php esc_html_e('Email', 'twork-points'); ?></th>
                        <th><?php esc_html_e('Actions', 'twork-points'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (! empty($users)) : ?>
                        <?php foreach ($users as $user) : ?>
                            <tr>
                                <td><?php echo esc_html($user->display_name); ?></td>
                                <td><?php echo esc_html($user->user_email); ?></td>
                                <td>
                                    <a class="button button-small" href="<?php echo esc_url(add_query_arg(array('page' => 'twork-points-users', 's' => $search_query, 'user_id' => $user->ID), admin_url('admin.php'))); ?>"><?php esc_html_e('View', 'twork-points'); ?></a>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php else : ?>
                        <tr>
                            <td colspan="3"><?php esc_html_e('Enter a search query to find users.', 'twork-points'); ?></td>
                        </tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>

        <div class="twork-user-column">
            <h2><?php esc_html_e('User Details', 'twork-points'); ?></h2>
            <?php if ($selected_user instanceof WP_User) : ?>
                <div class="twork-user-summary">
                    <h3><?php echo esc_html($selected_user->display_name); ?></h3>
                    <p><strong><?php esc_html_e('Email:', 'twork-points'); ?></strong> <?php echo esc_html($selected_user->user_email); ?></p>
                    <p><strong><?php esc_html_e('Current Balance:', 'twork-points'); ?></strong> <?php echo esc_html(number_format_i18n($user_balance)); ?></p>
                    <p><strong><?php esc_html_e('User ID:', 'twork-points'); ?></strong> <?php echo esc_html($selected_user->ID); ?></p>
                </div>

                <h3><?php esc_html_e('Adjust Points', 'twork-points'); ?></h3>
                <?php if (current_user_can('manage_users') || current_user_can('manage_woocommerce') || current_user_can('manage_options')) : ?>
                    <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" class="twork-adjust-form">
                        <?php wp_nonce_field('twork_points_adjust_user_points'); ?>
                        <input type="hidden" name="action" value="twork_points_adjust_user_points" />
                        <input type="hidden" name="user_id" value="<?php echo esc_attr($selected_user->ID); ?>" />
                        <input type="hidden" name="redirect_to" value="<?php echo esc_attr(add_query_arg(array('page' => 'twork-points-users', 's' => $search_query, 'user_id' => $selected_user->ID), admin_url('admin.php'))); ?>" />

                        <table class="form-table">
                            <tr>
                                <th><label for="twork-adjust-points"><?php esc_html_e('Points', 'twork-points'); ?></label></th>
                                <td>
                                    <input type="number" name="points" id="twork-adjust-points" value="0" />
                                    <p class="description"><?php esc_html_e('Use positive numbers to add points, negative numbers to deduct points.', 'twork-points'); ?></p>
                                    <p class="twork-adjust-help"><?php esc_html_e('Adjustments are logged with your user name and the reason below so other operators can audit the change later.', 'twork-points'); ?></p>
                                </td>
                            </tr>
                            <tr>
                                <th><label for="twork-adjust-reason"><?php esc_html_e('Reason', 'twork-points'); ?></label></th>
                                <td>
                                    <input type="text" class="regular-text" name="reason" id="twork-adjust-reason" placeholder="<?php esc_attr_e('Optional note for audit trail', 'twork-points'); ?>" />
                                </td>
                            </tr>
                        </table>

                        <?php submit_button(__('Apply Adjustment', 'twork-points')); ?>
                    </form>
                <?php else : ?>
                    <p><?php esc_html_e('You can view this customer’s points history but do not have permission to adjust their balance.', 'twork-points'); ?></p>
                <?php endif; ?>

                <h3><?php esc_html_e('Recent Transactions', 'twork-points'); ?></h3>
                <table class="widefat fixed striped">
                    <thead>
                        <tr>
                            <th><?php esc_html_e('Date', 'twork-points'); ?></th>
                            <th><?php esc_html_e('Type', 'twork-points'); ?></th>
                            <th><?php esc_html_e('Points', 'twork-points'); ?></th>
                            <th><?php esc_html_e('Description', 'twork-points'); ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (! empty($user_transactions)) : ?>
                            <?php foreach ($user_transactions as $transaction) : ?>
                                <tr>
                                    <td><?php echo esc_html(date_i18n(get_option('date_format'), strtotime($transaction['created_at']))); ?></td>
                                    <td><span class="twork-type-badge twork-type-<?php echo esc_attr($transaction['type']); ?>"><?php echo esc_html(ucfirst($transaction['type'])); ?></span></td>
                                    <td><?php echo esc_html(number_format_i18n($transaction['points'])); ?></td>
                                    <td><?php echo esc_html($transaction['description']); ?></td>
                                </tr>
                            <?php endforeach; ?>
                        <?php else : ?>
                            <tr>
                                <td colspan="4"><?php esc_html_e('No transactions found for this user.', 'twork-points'); ?></td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            <?php else : ?>
                <p><?php esc_html_e('Select a user from the list to view details and manage their points.', 'twork-points'); ?></p>
            <?php endif; ?>
        </div>
    </div>
</div>
