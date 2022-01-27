# frozen_string_literal: true

module Onebox
  module Engine
    class GoogleDriveOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp(/^(https?:)?\/\/(drive\.google\.com)\/file\/d\/(?<key>[\w-]*)\/.+$/)
      always_https

      protected

      def data
        og_data = get_opengraph
        title = og_data.title || "Google Drive"
        title = "#{og_data.title} (video)" if og_data.type =~ /^video[\/\.]/
        description = og_data.description || "Google Drive file."

        {
          link: link,
          title: title,
          description: Onebox::Helpers.truncate(description, 250),
          image: og_data.image
        }
      end
    end
  end
end
