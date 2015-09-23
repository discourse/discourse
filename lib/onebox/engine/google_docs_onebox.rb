module Onebox
  module Engine
    class GoogleDocsOnebox
      include Engine

      class << self
        def supported_endpoints
          %w(spreadsheets document forms presentation)
        end

        def embed_widths
          @embed_widths ||= {
            spreadsheets: 800,
            document: 800,
            presentation: 960,
            forms: 760,
          }
        end

        def embed_heights
          @embed_heights ||= {
            spreadsheets: 600,
            document: 600,
            presentation: 749,
            forms: 500,
          }
        end

        def short_types
          @shorttypes ||= {
            spreadsheets: :sheets,
            document: :docs,
            presentation: :slides,
            forms: :forms,
          }
        end
      end

      matches_regexp /^(https?:)?\/\/(docs\.google\.com)\/(?<endpoint>(#{supported_endpoints.join('|')}))\/d\/((?<key>[\w-]*)).+$/
      always_https

      def to_html
        if document?
          "<iframe class='gdocs-onebox document-onebox' src='https://docs.google.com/document/d/#{key}/pub?embedded=true' style='border: 0' width='#{width}' height='#{height}' frameborder='0' scrolling='yes'>#{placeholder_html}</iframe>"
        elsif spreadsheet?
          "<iframe class='gdocs-onebox spreadsheet-onebox' src='https://docs.google.com/spreadsheet/ccc?key=#{key}&usp=sharing&rm=minimal' style='border: 0' width='#{width}' height='#{height}' frameborder='0' scrolling='yes'>#{placeholder_html}</iframe>"
        elsif presentation?
          "<iframe class='gdocs-onebox presentation-onebox' src='https://docs.google.com/presentation/d/#{key}/embed?start=false&loop=false&delayms=3000' frameborder='0' width='#{width}' height='#{height}' allowfullscreen='true' mozallowfullscreen='true' webkitallowfullscreen='true'>#{placeholder_html}</iframe>"
        elsif forms?
          "<iframe class='gdocs-onebox forms-onebox' src='https://docs.google.com/forms/d/#{key}/viewform?embedded=true' width='#{width}' height='#{height}' frameborder='0' marginheight='0' marginwidth='0' scrolling='yes'>#{placeholder_html}</iframe>"
        end
      end

      def placeholder_html
        <<HTML
<div placeholder><div class='gdocs-onebox gdocs-onebox-splash' style='display:table-cell;vertical-align:middle;width:#{width}px;height:#{height}px'>
<div style='text-align:center;'>
<div class='gdocs-onebox-logo g-#{shorttype}-logo'></div>
<p>Google #{shorttype.capitalize}</p>
<p><a href="https://docs.google.com/#{doc_type}/d/#{key}">#{key}</a></p>
</div></div></div>
HTML
      end

      protected

      def doc_type
        @doc_type ||= match[:endpoint].to_sym
      end

      def shorttype
        GoogleDocsOnebox.short_types[doc_type]
      end

      def width
        GoogleDocsOnebox.embed_widths[doc_type]
      end

      def height
        GoogleDocsOnebox.embed_heights[doc_type]
      end

      def spreadsheet?
        doc_type == :spreadsheets
      end

      def document?
        doc_type == :document
      end

      def presentation?
        doc_type == :presentation
      end

      def forms?
        doc_type == :forms
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