# frozen_string_literal: true

require_relative "configuration"

module BulkImport::DiscourseMerge
  module Media
    def self.remote_url(url, origin)
      uri = URI.parse(url.to_s)
      if url.to_s.empty? || uri.userinfo || (uri.scheme && !%w[http https].include?(uri.scheme))
        raise Error, "Upload URL must be an HTTP URL or a source-relative path: #{url.inspect}"
      end
      URI.join(origin.delete_suffix("/") + "/", url).to_s
    rescue URI::InvalidURIError => error
      raise Error, "Invalid upload URL: #{error.message}"
    end

    def self.delivery_url(url, secure, target, origin)
      final = remote_url(url, origin)
      if secure
        return(
          "#{origin.delete_suffix("/")}/secure-uploads/#{URI.parse(final).path.delete_prefix("/")}"
        )
      end
      if target["cdn"].present?
        base = [target.fetch("origin"), target["folder"].presence].compact.join("/") + "/"
        schemeless = final.sub(/\Ahttps?:/, "")
        if schemeless.start_with?(base)
          return File.join(target["cdn"], schemeless.delete_prefix(base))
        end
      end
      final
    end

    def self.validate_reuse!(incoming, existing)
      unless incoming.fetch("sha1") == existing.fetch("sha1") &&
               incoming.fetch("filesize").to_i == existing.fetch("filesize").to_i
        raise Error,
              "Upload SHA-1 collision has inconsistent size metadata: #{incoming.fetch("id")}"
      end
    end
  end
end
