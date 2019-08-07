# frozen_string_literal: true

# this is a quick backport of a new method introduced in Rails 6
# to be removed after we upgrade to Rails 6
if ! defined? ActionView::Base.with_view_paths
  class ActionView::Base
    class << self
      alias with_view_paths new
    end
  end
end

# backport of https://github.com/rails/rails/commit/890485cfce4c361c03a41ec23b0ba187007818cc
if !defined? ActionDispatch::Http::ContentDisposition
  module ActionDispatch
    module Http
      class ContentDisposition
        def self.format(disposition:, filename:)
          new(disposition: disposition, filename: filename).to_s
        end

        attr_reader :disposition, :filename

        def initialize(disposition:, filename:)
          @disposition = disposition
          @filename = filename
        end

        TRADITIONAL_ESCAPED_CHAR = /[^ A-Za-z0-9!#$+.^_`|~-]/

        def ascii_filename
          'filename="' + percent_escape(I18n.transliterate(filename), TRADITIONAL_ESCAPED_CHAR) + '"'
        end

        RFC_5987_ESCAPED_CHAR = /[^A-Za-z0-9!#$&+.^_`|~-]/

        def utf8_filename
          "filename*=UTF-8''" + percent_escape(filename, RFC_5987_ESCAPED_CHAR)
        end

        def to_s
          if filename
            "#{disposition}; #{ascii_filename}; #{utf8_filename}"
          else
            "#{disposition}"
          end
        end

        private
        def percent_escape(string, pattern)
          string.gsub(pattern) do |char|
            char.bytes.map { |byte| "%%%02X" % byte }.join
          end
        end
      end
    end
  end

  module ActionController
    module DataStreaming
      private
      def send_file_headers!(options)
        type_provided = options.has_key?(:type)

        content_type = options.fetch(:type, DEFAULT_SEND_FILE_TYPE)
        self.content_type = content_type
        response.sending_file = true

        raise ArgumentError, ":type option required" if content_type.nil?

        if content_type.is_a?(Symbol)
          extension = Mime[content_type]
          raise ArgumentError, "Unknown MIME type #{options[:type]}" unless extension
          self.content_type = extension
        else
          if !type_provided && options[:filename]
            # If type wasn't provided, try guessing from file extension.
            content_type = Mime::Type.lookup_by_extension(File.extname(options[:filename]).downcase.delete(".")) || content_type
          end
          self.content_type = content_type
        end

        disposition = options.fetch(:disposition, DEFAULT_SEND_FILE_DISPOSITION)
        if disposition
          headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(disposition: disposition, filename: options[:filename])
        end

        headers["Content-Transfer-Encoding"] = "binary"

        # Fix a problem with IE 6.0 on opening downloaded files:
        # If Cache-Control: no-cache is set (which Rails does by default),
        # IE removes the file it just downloaded from its cache immediately
        # after it displays the "open/save" dialog, which means that if you
        # hit "open" the file isn't there anymore when the application that
        # is called for handling the download is run, so let's workaround that
        response.cache_control[:public] ||= false
      end
    end
  end

  module ActiveStorage
    class Service
      private
      def content_disposition_with(type: "inline", filename:)
        disposition = (type.to_s.presence_in(%w( attachment inline )) || "inline")
        ActionDispatch::Http::ContentDisposition.format(disposition: disposition, filename: filename.sanitized)
      end
    end
  end
end
