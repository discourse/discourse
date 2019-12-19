# frozen_string_literal: true

module HasUrl
  extend ActiveSupport::Concern

  class_methods do
    def extract_url(url)
      url.match(self::URL_REGEX)
    end

    def extract_sha1(path)
      data = extract_url(path)
      return if data.blank?

      sha1 = data[2]
      return if sha1&.length != Upload::SHA1_LENGTH

      sha1
    end

    def get_from_url(url)
      return if url.blank?

      uri = begin
        URI(UrlHelper.unencode(url))
      rescue URI::Error
      end

      return if uri&.path.blank?
      data = extract_url(uri.path)

      if data.blank?
        result = nil
        result ||= self.find_by(url: uri.path)
        return result
      end

      result = nil

      if self.name == "Upload"
        sha1 = data[2]
        result = self.find_by(sha1: sha1) if sha1&.length == Upload::SHA1_LENGTH
      end

      result || self.find_by("url LIKE ?", "%#{data[1]}")
    end
  end
end
