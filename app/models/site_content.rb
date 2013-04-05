require_dependency 'site_content_type'
require_dependency 'site_content_class_methods'

class SiteContent < ActiveRecord::Base
  extend SiteContentClassMethods

  set_primary_key :content_type
  validates_presence_of :content

  def self.formats
    @formats ||= Enum.new(:plain, :markdown, :html, :css)
  end

  content_type :usage_tips, :markdown, default_18n_key: 'system_messages.usage_tips.text_body_template'
  content_type :welcome_user, :markdown, default_18n_key: 'system_messages.welcome_user.text_body_template'
  content_type :welcome_invite, :markdown, default_18n_key: 'system_messages.welcome_invite.text_body_template'
  content_type :education_new_topic, :markdown, default_18n_key: 'education.new-topic'
  content_type :education_new_reply, :markdown, default_18n_key: 'education.new-reply'

  def site_content_type
    @site_content_type ||= SiteContent.content_types.find {|t| t.content_type == content_type.to_sym}
  end

end
