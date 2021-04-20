# frozen_string_literal: true

module Onebox
  module Engine
    class PdfOnebox
      include Engine
      include LayoutSupport

      matches_regexp(/^(https?:)?\/\/.*\.pdf(\?.*)?$/i)
      always_https

      private

      def data
        begin
          size = Onebox::Helpers.fetch_content_length(@url)
        rescue
          raise "Unable to read pdf file: #{@url}"
        end

        {
          link: link,
          title: File.basename(uri.path),
          filesize: size ? Onebox::Helpers.pretty_filesize(size.to_i) : nil,
        }
      end
    end
  end
end
