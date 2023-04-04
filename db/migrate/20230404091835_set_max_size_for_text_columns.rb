# frozen_string_literal: true

class SetMaxSizeForTextColumns < ActiveRecord::Migration[7.0]
  DEFAULT_LIMIT = 1_000_000

  def up
    change_column :api_keys, :description, :string, limit: DEFAULT_LIMIT
    change_column :badges, :description, :string, limit: DEFAULT_LIMIT
    change_column :badges, :long_description, :string, limit: DEFAULT_LIMIT
    change_column :badges, :query, :string, limit: DEFAULT_LIMIT
    change_column :badge_groupings, :description, :string, limit: DEFAULT_LIMIT
    change_column :category_custom_fields, :value, :string, limit: 10_000
    change_column :category_search_data, :locale, :string, limit: 10
    change_column :category_search_data, :raw_data, :string, limit: DEFAULT_LIMIT
    change_column :categories, :description, :string, limit: DEFAULT_LIMIT
    change_column :categories, :topic_template, :string, limit: 300_000
    change_column :drafts, :data, :string, limit: 400_000
    change_column :email_logs, :bcc_addresses, :string, limit: DEFAULT_LIMIT
    change_column :email_logs, :cc_addresses, :string, limit: DEFAULT_LIMIT
    change_column :email_logs, :raw, :string, limit: DEFAULT_LIMIT
    change_column :form_templates, :template, :string, limit: 2000
    change_column :groups, :automatic_membership_email_domains, :string, limit: 100
    change_column :groups, :bio_cooked, :string, limit: DEFAULT_LIMIT
    change_column :groups, :bio_raw, :string, limit: 3000
    change_column :groups, :imap_last_error, :string, limit: DEFAULT_LIMIT
    change_column :groups, :membership_request_template, :string, limit: 3000
    change_column :group_custom_fields, :value, :string, limit: DEFAULT_LIMIT
    change_column :group_histories, :new_value, :string, limit: DEFAULT_LIMIT
    change_column :group_histories, :prev_value, :string, limit: DEFAULT_LIMIT
    change_column :group_requests, :reason, :string, limit: 280
    change_column :incoming_emails, :cc_addresses, :string, limit: DEFAULT_LIMIT
    change_column :incoming_emails, :error, :string, limit: DEFAULT_LIMIT
    change_column :incoming_emails, :from_address, :string, limit: DEFAULT_LIMIT
    change_column :incoming_emails, :message_id, :string, limit: DEFAULT_LIMIT
    change_column :incoming_emails, :rejection_message, :string, limit: DEFAULT_LIMIT
    change_column :incoming_emails, :subject, :string, limit: DEFAULT_LIMIT
    change_column :incoming_emails, :to_addresses, :string, limit: DEFAULT_LIMIT
    change_column :invites, :custom_message, :string, limit: 1000
    change_column :javascript_caches, :content, :string, limit: DEFAULT_LIMIT
    change_column :javascript_caches, :source_map, :string, limit: DEFAULT_LIMIT
    change_column :plugin_store_rows, :value, :string, limit: DEFAULT_LIMIT

    BadgePostsViewManager.drop!
    change_column :posts, :cooked, :string, limit: DEFAULT_LIMIT
    change_column :posts, :raw, :string, limit: 300_000
    change_column :posts, :raw_email, :string, limit: DEFAULT_LIMIT
    BadgePostsViewManager.create!

    change_column :post_custom_fields, :value, :string, limit: DEFAULT_LIMIT
    change_column :post_details, :extra, :string, limit: DEFAULT_LIMIT
    change_column :post_revisions, :modifications, :string, limit: DEFAULT_LIMIT
    change_column :post_search_data, :raw_data, :string, limit: DEFAULT_LIMIT
    change_column :remote_themes, :last_error_text, :string, limit: DEFAULT_LIMIT
    change_column :remote_themes, :private_key, :string, limit: DEFAULT_LIMIT
    change_column :reviewables, :reject_reason, :string, limit: 3000
    change_column :single_sign_on_records, :last_payload, :string, limit: DEFAULT_LIMIT
    change_column :site_settings, :value, :string, limit: 5000
    change_column :skipped_email_logs, :custom_reason, :string, limit: DEFAULT_LIMIT
    change_column :stylesheet_cache, :content, :string, limit: DEFAULT_LIMIT
    change_column :stylesheet_cache, :source_map, :string, limit: 1_500_000
    change_column :tag_search_data, :locale, :string, limit: 10
    change_column :tag_search_data, :raw_data, :string, limit: DEFAULT_LIMIT
    change_column :theme_fields, :value, :string, limit: 300_000
    change_column :theme_fields, :value_baked, :string, limit: DEFAULT_LIMIT
    change_column :theme_settings, :value, :string, limit: 6000
    change_column :topic_custom_fields, :value, :string, limit: DEFAULT_LIMIT
    change_column :topic_search_data, :raw_data, :string, limit: DEFAULT_LIMIT
    change_column :translation_overrides, :compiled_js, :string, limit: DEFAULT_LIMIT
    change_column :uploads, :dominant_color, :string, limit: 6
    change_column :user_custom_fields, :value, :string, limit: DEFAULT_LIMIT
    change_column :user_histories, :details, :string, limit: DEFAULT_LIMIT
    change_column :user_histories, :new_value, :string, limit: DEFAULT_LIMIT
    change_column :user_histories, :previous_value, :string, limit: DEFAULT_LIMIT
    change_column :user_histories, :subject, :string, limit: DEFAULT_LIMIT
    change_column :user_profiles, :bio_cooked, :string, limit: DEFAULT_LIMIT
    change_column :user_profiles, :bio_raw, :string, limit: 3000
    change_column :user_search_data, :locale, :string, limit: 10
    change_column :user_search_data, :raw_data, :string, limit: DEFAULT_LIMIT
    change_column :web_hook_events, :payload, :string, limit: DEFAULT_LIMIT
    change_column :web_hook_events, :response_body, :string, limit: DEFAULT_LIMIT
  rescue ActiveRecord::ValueTooLong
    puts <<~MESSAGE

    \033[91;1m
    ===========================================================================
      An error occurred while setting limits on some TEXT columns.

      This is happening because there are existing data that are bigger than
      the new default limit.

      The line just before this message should provide which change is causing
      the error.

      Please visit <URL> to see how to resolve this issue.
    ===========================================================================
    \033[0m

    MESSAGE
  end

  def down
    change_column :api_keys, :description, :text
    change_column :badges, :description, :text
    change_column :badges, :long_description, :text
    change_column :badges, :query, :text
    change_column :badge_groupings, :description, :text
    change_column :category_custom_fields, :value, :text
    change_column :category_search_data, :locale, :text
    change_column :category_search_data, :raw_data, :text
    change_column :categories, :description, :text
    change_column :categories, :topic_template, :text
    change_column :drafts, :data, :text
    change_column :email_logs, :bcc_addresses, :text
    change_column :email_logs, :cc_addresses, :text
    change_column :email_logs, :raw, :text
    change_column :form_templates, :template, :text
    change_column :groups, :automatic_membership_email_domains, :text
    change_column :groups, :bio_cooked, :text
    change_column :groups, :bio_raw, :text
    change_column :groups, :imap_last_error, :text
    change_column :groups, :membership_request_template, :text
    change_column :group_custom_fields, :value, :text
    change_column :group_histories, :new_value, :text
    change_column :group_histories, :prev_value, :text
    change_column :group_requests, :reason, :text
    change_column :incoming_emails, :cc_addresses, :text
    change_column :incoming_emails, :error, :text
    change_column :incoming_emails, :from_address, :text
    change_column :incoming_emails, :message_id, :text
    change_column :incoming_emails, :rejection_message, :text
    change_column :incoming_emails, :subject, :text
    change_column :incoming_emails, :to_addresses, :text
    change_column :invites, :custom_message, :text
    change_column :javascript_caches, :content, :text
    change_column :javascript_caches, :source_map, :text
    change_column :plugin_store_rows, :value, :text

    BadgePostsViewManager.drop!
    change_column :posts, :cooked, :text
    change_column :posts, :raw, :text
    change_column :posts, :raw_email, :text
    BadgePostsViewManager.create!

    change_column :post_custom_fields, :value, :text
    change_column :post_details, :extra, :text
    change_column :post_revisions, :modifications, :text
    change_column :post_search_data, :raw_data, :text
    change_column :remote_themes, :last_error_text, :text
    change_column :remote_themes, :private_key, :text
    change_column :reviewables, :reject_reason, :text
    change_column :single_sign_on_records, :last_payload, :text
    change_column :site_settings, :value, :text
    change_column :skipped_email_logs, :custom_reason, :text
    change_column :stylesheet_cache, :content, :text
    change_column :stylesheet_cache, :source_map, :text
    change_column :tag_search_data, :locale, :text
    change_column :tag_search_data, :raw_data, :text
    change_column :theme_fields, :value, :text
    change_column :theme_fields, :value_baked, :text
    change_column :theme_settings, :value, :text
    change_column :topic_custom_fields, :value, :text
    change_column :topic_search_data, :raw_data, :text
    change_column :translation_overrides, :compiled_js, :text
    change_column :uploads, :dominant_color, :text
    change_column :user_custom_fields, :value, :text
    change_column :user_histories, :details, :text
    change_column :user_histories, :new_value, :text
    change_column :user_histories, :previous_value, :text
    change_column :user_histories, :subject, :text
    change_column :user_profiles, :bio_cooked, :text
    change_column :user_profiles, :bio_raw, :text
    change_column :user_search_data, :locale, :text
    change_column :user_search_data, :raw_data, :text
    change_column :web_hook_events, :payload, :text
    change_column :web_hook_events, :response_body, :text
  end
end
