# frozen_string_literal: true
class JavascriptCache < ActiveRecord::Base
  belongs_to :theme_field
  belongs_to :theme

  validate :content_cannot_be_nil

  before_save :update_digest

  def url
    "#{GlobalSetting.cdn_url}#{Discourse.base_path}#{path}"
  end

  def local_url
    "#{Discourse.base_path}#{path}"
  end

  private

  def path
    "/theme-javascripts/#{digest}.js?__ws=#{Discourse.current_hostname}"
  end

  def update_digest
    self.digest =
      Digest::SHA1.hexdigest("#{content}|#{GlobalSetting.asset_url_salt}") if content_changed?
  end

  def content_cannot_be_nil
    errors.add(:content, :empty) if content.nil?
  end
end

# == Schema Information
#
# Table name: javascript_caches
#
#  id             :bigint           not null, primary key
#  theme_field_id :bigint
#  digest         :string
#  content        :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  theme_id       :bigint
#  source_map     :text
#
# Indexes
#
#  index_javascript_caches_on_digest          (digest)
#  index_javascript_caches_on_theme_field_id  (theme_field_id) UNIQUE
#  index_javascript_caches_on_theme_id        (theme_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (theme_field_id => theme_fields.id) ON DELETE => cascade
#  fk_rails_...  (theme_id => themes.id) ON DELETE => cascade
#
