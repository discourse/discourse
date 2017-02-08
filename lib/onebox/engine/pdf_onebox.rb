module Onebox
  module Engine
    class PdfOnebox
      include Engine
      include LayoutSupport

      matches_regexp(/^(https?:)?\/\/.*\.pdf(\?.*)?$/i)
      always_https

      private

      def data
        html_entities = HTMLEntities.new
        pdf_info = get_pdf_info
        raise "Unable to read pdf file: #{@url}" if pdf_info.nil?

        result = { link: link,
                   title: pdf_info[:name],
                   filesize: pdf_info[:filesize]
                  }
        result
      end

      def get_pdf_info
        uri = URI.parse(@url)
        size = Onebox::Helpers.fetch_content_length(@url)
        return {filesize: Onebox::Helpers.pretty_filesize(size.to_i), name: File.basename(uri.path)}
      rescue
        nil
      end
    end
  end
end
