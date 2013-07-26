require_dependency 'oneboxer/base_onebox'

module Oneboxer
  class AudioOnebox < BaseOnebox

    matcher /^https?:\/\/.*\.mp3$/

    def onebox
      "<audio controls><source src='#{@url}'><a href='#{@url}'>#{@url}</a></audio>"
    end
  end
end
