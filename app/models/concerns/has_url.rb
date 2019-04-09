module HasUrl
  extend ActiveSupport::Concern

  class_methods do
    def extract_url(url)
      url.match(self::URL_REGEX)
    end

    def get_from_url(url)
      return if url.blank?

      uri = begin
        URI(URI.unescape(url))
      rescue URI::Error
      end

      return if uri&.path.blank?
      data = extract_url(uri.path)
      return if data.blank?
      result = nil

      if self.name == "Upload"
        sha1 = data[2]
        result = self.find_by(sha1: sha1) if sha1&.length == Upload::SHA1_LENGTH
      end

      result || self.find_by("url LIKE ?", "%#{data[1]}")
    end
  end
end
