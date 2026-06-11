require_relative './node'

module Capybara
  module Playwright
    class ShadowRootNode < Node
      def initialize(driver, internal_logger, page, element)
        super
        @shadow_root_element = element.evaluate_handle('el => el.shadowRoot')
      end

      def all_text
        assert_element_not_stale {
          text = @shadow_root_element.text_content
          text.to_s.gsub(/[\u200b\u200e\u200f]/, '')
              .gsub(/[\ \n\f\t\v\u2028\u2029]+/, ' ')
              .gsub(/\A[[:space:]&&[^\u00a0]]+/, '')
              .gsub(/[[:space:]&&[^\u00a0]]+\z/, '')
              .tr("\u00a0", ' ')
        }
      end

      def visible_text
        assert_element_not_stale {

          return '' unless visible?

          # https://github.com/teamcapybara/capybara/blob/1c164b608fa6452418ec13795b293655f8a0102a/lib/capybara/rack_test/node.rb#L18
          displayed_text = @shadow_root_element.text_content.to_s.
                              gsub(/[\u200b\u200e\u200f]/, '').
                              gsub(/[\ \n\f\t\v\u2028\u2029]+/, ' ')
          displayed_text.squeeze(' ')
            .gsub(/[\ \n]*\n[\ \n]*/, "\n")
            .gsub(/\A[[:space:]&&[^\u00a0]]+/, '')
            .gsub(/[[:space:]&&[^\u00a0]]+\z/, '')
            .tr("\u00a0", ' ')
        }
      end
    end
  end
end
