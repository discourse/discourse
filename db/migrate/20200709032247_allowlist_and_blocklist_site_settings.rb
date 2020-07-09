# frozen_string_literal: true

class AllowlistAndBlocklistSiteSettings < ActiveRecord::Migration[6.0]
  NAMES_MAP = {
    'email_domains_blacklist': 'email_domains_blocklist',
    'email_domains_whitelist': 'email_domains_allowlist',
    'unicode_username_character_whitelist': 'unicode_username_character_allowlist',
    'user_website_domains_whitelist': 'user_website_domains_allowlist',
    'whitelisted_link_domains': 'allowlisted_link_domains',
    'embed_whitelist_selector': 'embed_allowlist_selector',
    'auto_generated_whitelist': 'auto_generated_allowlist',
    'attachment_content_type_blacklist': 'attachment_content_type_blocklist',
    'attachment_filename_blacklist': 'attachment_filename_blocklist',
    'use_admin_ip_whitelist': 'use_admin_ip_allowlist',
    'blacklist_ip_blocks': 'blocklist_ip_blocks',
    'whitelist_internal_hosts': 'allowlist_internal_hosts',
    'whitelisted_crawler_user_agents': 'allowlisted_crawler_user_agents',
    'blacklisted_crawler_user_agents': 'blocklisted_crawler_user_agents',
    'onebox_domains_blacklist': 'onebox_domains_blocklist',
    'inline_onebox_domains_whitelist': 'inline_onebox_domains_allowlist',
    'white_listed_spam_host_domains': 'allow_listed_spam_host_domains',
    'embed_blacklist_selector': 'embed_blocklist_selector',
    'embed_classname_whitelist': 'embed_classname_allowlist',
  }

  def up
    NAMES_MAP.each_pair do |key, value|
      SiteSetting.where(name: key).update(name: value)
    end
  end

  def down
    NAMES_MAP.each_pair do |key, value|
      SiteSetting.where(name: value).update(name: key)
    end
  end
end
