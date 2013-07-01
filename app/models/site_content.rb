require_dependency 'site_content_type'
require_dependency 'site_content_class_methods'

class SiteContent < ActiveRecord::Base
  extend SiteContentClassMethods

  self.primary_key = 'content_type'

  validates_presence_of :content

  def self.formats
    @formats ||= Enum.new(:plain, :markdown, :html, :css)
  end

  add_content_type :usage_tips, default_18n_key: 'system_messages.usage_tips.text_body_template'
  add_content_type :education_new_topic, default_18n_key: 'education.new-topic'
  add_content_type :education_new_reply, default_18n_key: 'education.new-reply'
  add_content_type :tos_user_content_license, default_18n_key: 'terms_of_service.user_content_license'
  add_content_type :tos_miscellaneous, default_18n_key: 'terms_of_service.miscellaneous'
  add_content_type :login_required_welcome_message, default_18n_key: 'login_required.welcome_message'
  add_content_type :privacy_policy, allow_blank: true
  add_content_type :faq, allow_blank: true

  def site_content_type
    @site_content_type ||= SiteContent.content_types.find {|t| t.content_type == content_type.to_sym}
  end

end

# == Schema Information
#
# Table name: site_contents
#
#  content_type :string(255)      not null, primary key
#  content      :text             not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_site_contents_on_content_type  (content_type) UNIQUE
#

