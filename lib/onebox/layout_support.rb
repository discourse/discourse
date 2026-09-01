# frozen_string_literal: true

module Onebox
  module LayoutSupport
    class << self
      def max_text
        500
      end
    end

    def layout
      @layout ||= Layout.new(self.class.onebox_name, data)
    end

    def to_html
      layout.to_html
    end
  end
end
