# frozen_string_literal: true
class JavascriptCache < ActiveRecord::Base
  belongs_to :theme_field

  validate :content_cannot_be_nil

  before_save :update_digest

  def url
    "#{GlobalSetting.cdn_url}#{GlobalSetting.relative_url_root}/theme-javascripts/#{digest}.js?__ws=#{Discourse.current_hostname}"
  end

  private

  def update_digest
    self.digest = Digest::SHA1.hexdigest(content) if content_changed?
  end

  def content_cannot_be_nil
    errors.add(:content, :empty) if content.nil?
  end
end

# == Schema Information
#
# Table name: javascript_caches
#
#  id             :bigint(8)        not null, primary key
#  theme_field_id :bigint(8)        not null
#  digest         :string
#  content        :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_javascript_caches_on_digest          (digest)
#  index_javascript_caches_on_theme_field_id  (theme_field_id)
#
