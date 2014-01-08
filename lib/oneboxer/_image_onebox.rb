require_dependency 'oneboxer/base_onebox'

module Oneboxer
  class ImageOnebox < BaseOnebox

    matcher /^(https?:)?\/\/.+\.(png|jpg|jpeg|gif|bmp|tif|tiff)$/i

    def onebox
      Oneboxer::BaseOnebox.image_html(@url, nil, @url)
    end

  end
end
