module Onebox
  module Engine
    class SlidesOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/slides\.com\/[\p{Alnum}_\-]+\/[\p{Alnum}_\-]+$/)


      def to_html
        if uri.path =~ /^\/[\p{Alnum}_\-]+\/[\p{Alnum}_\-]+$/
          "<iframe src=\"//slides.com#{uri.path}/embed?style=light\" width=\"576\" height=\"420\" scrolling=\"no\" frameborder=\"0\" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>"
        end
      end

      def placeholder_html
        # get_opengraph_data
        "<img src='#{get_opengraph_data[:images].first}'>"
      end

      private

      def get_opengraph_data
        return @opengraph_data if @opengraph_data
        response = Onebox::Helpers.fetch_response(url)
        html_doc = Nokogiri::HTML(response.body)

        @opengraph_data = parse_open_graph(html_doc, url)
      end
    end
  end
end
