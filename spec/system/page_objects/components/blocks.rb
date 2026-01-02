# frozen_string_literal: true

module PageObjects
  module Components
    class Blocks < PageObjects::Components::Base
      def has_block?(name)
        page.has_css?(".block-#{name}", wait: 5)
      end

      def has_no_block?(name)
        page.has_no_css?(".block-#{name}", wait: 5)
      end

      def block_text(name)
        find(".block-#{name}").text
      end

      def block_count(outlet_name)
        page.all("[class*='#{outlet_name}__block']").count
      end
    end
  end
end
