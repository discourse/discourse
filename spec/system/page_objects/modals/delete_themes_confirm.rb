# frozen_string_literal: true

module PageObjects
  module Modals
    class DeleteThemesConfirm < PageObjects::Pages::Base
      def has_theme?(name)
        PlaywrightMatchers.contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(".d-modal li").filter(visible: true),
        )
      end

      def confirm
        browser_root.locator(".d-modal__footer .btn-primary").filter(visible: true).click
      end
    end
  end
end
