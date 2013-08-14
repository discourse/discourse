require_relative "engine/example"
require_relative "engine/amazon"

module Onebox
  module Engine
    def to_html
      @view
    end
  end
end
