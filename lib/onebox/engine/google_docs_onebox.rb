module Onebox
  module Engine
    class GoogleDocsOnebox
      include Engine

      def self.supported_endpoints
        %w(spreadsheets document forms presentation)
      end

      matches_regexp /^(https?:)?\/\/(docs\.google\.com)\/(?<endpoint>(#{supported_endpoints.join('|')}))\/d\/((?<key>[\w-]*)).+$/
      always_https

      def to_html
        if document?
          "<iframe class='gdocs-onebox document-onebox' src='https://docs.google.com/document/d/#{key}/pub?embedded=true' style='border: 0' width='800' height='600' frameborder='0' scrolling='yes' ></iframe>"
        elsif spreadsheet?
          "<iframe class='gdocs-onebox spreadsheet-onebox' src='https://docs.google.com/spreadsheet/ccc?key=#{key}&usp=sharing&rm=minimal' style='border: 0' width='800' height='600' frameborder='0' scrolling='yes' ></iframe>"
        elsif presentation?
          "<iframe class='gdocs-onebox presentation-onebox' src='https://docs.google.com/presentation/d/#{key}/embed?start=false&loop=false&delayms=3000' frameborder='0' width='960' height='749' allowfullscreen='true' mozallowfullscreen='true' webkitallowfullscreen='true'></iframe>"
        elsif forms?
          "<iframe class='gdocs-onebox forms-onebox' src='https://docs.google.com/forms/d/#{key}/viewform?embedded=true' width='760' height='500' frameborder='0' marginheight='0' marginwidth='0' scrolling='yes'>Loading...</iframe>"
        end
      end

      protected
      def spreadsheet?
        match[:endpoint] == 'spreadsheets'
      end

      def document?
        match[:endpoint] == 'document'
      end

      def presentation?
        match[:endpoint] == 'presentation'
      end

      def forms?
        match[:endpoint] == 'forms'
      end

      def key
        match[:key]
      end

      def match
        @match ||= @url.match(@@matcher)
      end
    end
  end
end