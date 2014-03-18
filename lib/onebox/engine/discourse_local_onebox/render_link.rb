module Onebox
  module Engine
    class DiscourseLocalOnebox
      class RenderLink
        def self.call(options={})
          new(options).call
        end

        def initialize(options={})
          @url = options.fetch(:url)
        end

        def call
          "<a href='#{url}'>#{url}</a>"
        end

        private
        attr_reader :url
      end
    end
  end
end
