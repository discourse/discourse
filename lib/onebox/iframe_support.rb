module Onebox
  module IFrameSupport

    # Generates the HTML for the iframe, complete with dimensions supplied from opengraph
    def to_html
      video = data[:video]
      if video
        video_url = video[:_value]

        if video_url

          html = "<iframe src=\"#{video_url}\" frameborder=\"0\" title=\"#{data[:title]}\""

          append_attribute(:width, html, video)
          append_attribute(:height, html, video)

          html << "></iframe>"
          return html
        end
      end

      return ""
    end


    private

    def append_attribute(attribute, html, video)
      if video[attribute] &&
         video[attribute].first &&
         val = video[attribute].first[:_value]

         html << " #{attribute.to_s}=\"#{val}\""
      end
    end

  end
end