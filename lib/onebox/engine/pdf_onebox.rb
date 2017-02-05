require 'pdf-reader'

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
        pdf_response = get_pdf_response
        raise "Unable to read pdf file: #{@url}" if pdf_response.nil?

        pdf_data = pdf_response.info
        result = { link: link }
        result['title'] = unless pdf_data[:Title].blank?
          html_entities.decode(Onebox::Helpers.truncate(pdf_data[:Title].force_encoding("UTF-8").scrub.strip, 80))
        else
          "PDF File"
        end
        result['description'] = html_entities.decode(Onebox::Helpers.truncate(pdf_data[:Subject].force_encoding("UTF-8").scrub.strip, 250)) rescue nil
        result['author'] = pdf_data[:Author] unless pdf_data[:Author].blank?
        result
      end

      def get_pdf_response
        PDF::Reader.new(open(@url, read_timeout: Onebox.options.timeout))
      rescue
        nil
      end
    end
  end
end
