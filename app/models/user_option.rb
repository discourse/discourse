class UserOption < ActiveRecord::Base
  self.primary_key = :user_id
  belongs_to :user
  before_create :set_defaults

  def set_defaults
    self.email_always = SiteSetting.default_email_always
    self.mailing_list_mode = SiteSetting.default_email_mailing_list_mode
    self.email_direct = SiteSetting.default_email_direct
    self.automatically_unpin_topics = SiteSetting.default_topics_automatic_unpin
    self.email_private_messages = SiteSetting.default_email_private_messages

    self.enable_quoting = SiteSetting.default_other_enable_quoting
    self.external_links_in_new_tab = SiteSetting.default_other_external_links_in_new_tab
    self.dynamic_favicon = SiteSetting.default_other_dynamic_favicon
    self.disable_jump_reply = SiteSetting.default_other_disable_jump_reply
    self.edit_history_public = SiteSetting.default_other_edit_history_public


    if SiteSetting.default_email_digest_frequency.to_i <= 0
      self.email_digests = false
    else
      self.email_digests = true
      self.digest_after_days ||= SiteSetting.default_email_digest_frequency.to_i
    end

    true
  end
end
