module Onebox
  module LayoutSupport

    def layout
      @layout ||= Layout.new(self.class.onebox_name, record, @cache)
    end

    def to_html
      layout.to_html
    end

  end
end
