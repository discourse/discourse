# frozen_string_literal: true

class EmbeddableHost < ActiveRecord::Base
  validate :host_must_be_valid
  belongs_to :category
  belongs_to :user, optional: true
  has_many :embeddable_host_tags
  has_many :tags, through: :embeddable_host_tags
  after_destroy :reset_embedding_settings

  before_validation do
    self.host.sub!(%r{\Ahttps?://}, "")
    self.host.sub!(%r{/.*\z}, "")
  end

  self.ignored_columns = ["path_whitelist"] # TODO: Remove when 20240212034010_drop_deprecated_columns has been promoted to pre-deploy

  def self.record_for_url(uri)
    if uri.is_a?(String)
      uri =
        begin
          URI(UrlHelper.normalized_encode(uri))
        rescue URI::Error, Addressable::URI::InvalidURIError
        end
    end

    return false unless uri.present?

    host = uri.host
    return false unless host.present?

    host << ":#{uri.port}" if uri.port.present? && uri.port != 80 && uri.port != 443

    path = uri.path
    path << "?" << uri.query if uri.query.present?

    where("lower(host) = ?", host).each do |eh|
      return eh if eh.allowed_paths.blank?

      path_regexp = Regexp.new(eh.allowed_paths)
      return eh if path_regexp.match(path) || path_regexp.match(UrlHelper.unencode(path))
    end

    nil
  end

  def self.url_allowed?(url)
    return false if url.nil?

    uri =
      begin
        URI(UrlHelper.normalized_encode(url))
      rescue URI::Error
      end

    uri.present? && record_for_url(uri).present?
  end

  private

  def reset_embedding_settings
    unless EmbeddableHost.exists?
      Embedding.settings.each { |s| SiteSetting.set(s.to_s, SiteSetting.defaults[s]) }
    end
  end

  def host_must_be_valid
    if host !~ /\A[a-z0-9]+([\-\.]+{1}[a-z0-9]+)*\.[a-z]{2,24}(:[0-9]{1,5})?(\/.*)?\Z/i &&
         host !~ /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(:[0-9]{1,5})?(\/.*)?\Z/ &&
         host !~ /\A([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.)?localhost(\:[0-9]{1,5})?(\/.*)?\Z/i
      errors.add(:host, I18n.t("errors.messages.invalid"))
    end
  end
end

# == Schema Information
#
# Table name: embeddable_hosts
#
#  id            :integer          not null, primary key
#  host          :string           not null
#  category_id   :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  class_name    :string
#  allowed_paths :string
#  user_id       :integer
#
