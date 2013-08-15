require_relative "engine/example"
require_relative "engine/amazon"
require_relative "engine/qik"
require_relative "engine/stackexchange"

module Onebox
  module Engine
    def to_html
      @view
    end
  end
end
