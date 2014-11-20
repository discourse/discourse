require_dependency 'site_text_type'
require_dependency 'site_text_class_methods'
require_dependency 'distributed_cache'

class SiteText < ActiveRecord::Base

  extend SiteTextClassMethods
  self.primary_key = 'text_type'

  validates_presence_of :value

  after_save do
    SiteText.text_for_cache.clear
  end

  def self.formats
    @formats ||= Enum.new(:plain, :markdown, :html, :css)
  end

  add_text_type :usage_tips, default_18n_key: 'system_messages.usage_tips.text_body_template'
  add_text_type :education_new_topic, default_18n_key: 'education.new-topic'
  add_text_type :education_new_reply, default_18n_key: 'education.new-reply'
  add_text_type :login_required_welcome_message, default_18n_key: 'login_required.welcome_message'
  add_text_type :top, allow_blank: true, format: :html
  add_text_type :bottom, allow_blank: true, format: :html
  add_text_type :head, allow_blank: true, format: :html

  def site_text_type
    @site_text_type ||= SiteText.find_text_type(text_type)
  end

end

# == Schema Information
#
# Table name: site_texts
#
#  text_type  :string(255)      not null, primary key
#  value      :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_site_texts_on_text_type  (text_type) UNIQUE
#
