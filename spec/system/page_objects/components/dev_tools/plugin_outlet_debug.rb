# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class PluginOutletDebug < PageObjects::Components::Base
        def hover_outlet(name)
          find(".plugin-outlet-debug[data-outlet-name='#{name}']").hover
          self
        end

        def has_outlets?(minimum: 1)
          page.has_css?(".plugin-outlet-debug", minimum: minimum)
        end

        def has_no_outlets?
          page.has_no_css?(".plugin-outlet-debug")
        end

        def has_tooltip?
          page.has_css?(".plugin-outlet-info__wrapper")
        end

        def has_wrapper_outlet?
          page.has_css?(".plugin-outlet-debug.--wrapper")
        end

        def has_github_link?
          page.has_css?(".plugin-outlet-info__heading .github-link")
        end

        def has_arg?(key:)
          page.has_css?(".block-debug-args__key", text: key)
        end

        def has_arg_value?(value:)
          page.has_css?(".block-debug-args__value", text: value)
        end

        def has_wrapper_label?
          page.has_css?(".plugin-outlet-info__wrapper", text: "(wrapper)")
        end
      end
    end
  end
end
