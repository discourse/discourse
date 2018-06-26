require_dependency 'url_helper'

class EmbeddableHost < ActiveRecord::Base
  validate :host_must_be_valid
  belongs_to :category

  before_validation do
    self.host.sub!(/^https?:\/\//, '')
    self.host.sub!(/\/.*$/, '')
  end

  def self.record_for_url(uri)

    if uri.is_a?(String)
      uri = begin
        URI(UrlHelper.escape_uri(uri))
      rescue URI::InvalidURIError
      end
    end
    return false unless uri.present?

    host = uri.host
    return false unless host.present?

    if uri.port.present? && uri.port != 80 && uri.port != 443
      host << ":#{uri.port}"
    end

    path = uri.path
    path << "?" << uri.query if uri.query.present?

    where("lower(host) = ?", host).each do |eh|
      return eh if eh.path_whitelist.blank?

      path_regexp = Regexp.new(eh.path_whitelist)
      return eh if path_regexp.match(path) || path_regexp.match(URI.unescape(path))
    end

    nil
  end

  def self.url_allowed?(url)
    # Work around IFRAME reload on WebKit where the referer will be set to the Forum URL
    return true if url&.starts_with?(Discourse.base_url)

    uri = begin
      URI(UrlHelper.escape_uri(url))
    rescue URI::InvalidURIError
    end

    uri.present? && record_for_url(uri).present?
  end

  private

  def host_must_be_valid
    if host !~ /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,10}(:[0-9]{1,5})?(\/.*)?\Z/i &&
       host !~ /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(:[0-9]{1,5})?(\/.*)?\Z/ &&
       host !~ /\A([a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.)?localhost(\:[0-9]{1,5})?(\/.*)?\Z/i
      errors.add(:host, I18n.t('errors.messages.invalid'))
    end
  end
end

# == Schema Information
#
# Table name: embeddable_hosts
#
#  id             :integer          not null, primary key
#  host           :string           not null
#  category_id    :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  path_whitelist :string
#  class_name     :string
#
