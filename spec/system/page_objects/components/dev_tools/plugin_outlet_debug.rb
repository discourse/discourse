# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class PluginOutletDebug < PageObjects::Components::Base
        def hover_outlet(name)
          browser_root
            .locator(".plugin-outlet-debug[data-outlet-name='#{name}']")
            .filter(visible: true)
            .hover
          self
        end

        def has_outlets?(minimum: 1)
          be_attached.matches?(
            browser_root.locator(".plugin-outlet-debug").filter(visible: true).nth(minimum - 1),
          )
        end

        def has_no_outlets?
          have_count(0).matches?(browser_root.locator(".plugin-outlet-debug").filter(visible: true))
        end

        def has_tooltip?
          have_count(0).does_not_match?(
            browser_root.locator(".outlet-info__wrapper").filter(visible: true),
          )
        end

        def has_wrapper_outlet?
          have_count(0).does_not_match?(
            browser_root.locator(".plugin-outlet-debug.--wrapper").filter(visible: true),
          )
        end

        def has_github_link?
          have_count(0).does_not_match?(
            browser_root.locator(".outlet-info__heading .github-link").filter(visible: true),
          )
        end

        def has_arg?(key:)
          contain_text([browser_text_pattern(key)], useInnerText: true).matches?(
            browser_root.locator(".outlet-args-table__key").filter(visible: true),
          )
        end

        def has_arg_value?(value:)
          contain_text([browser_text_pattern(value)], useInnerText: true).matches?(
            browser_root.locator(".outlet-args-table__value").filter(visible: true),
          )
        end

        def has_wrapper_label?
          contain_text([browser_text_pattern("(wrapper)")], useInnerText: true).matches?(
            browser_root.locator(".outlet-info__heading").filter(visible: true),
          )
        end
      end
    end
  end
end
