# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class BundleAnalyzer < PageObjects::Components::Base
        MODAL = ".bundle-analyzer-modal"

        def dismiss_development_warning
          find("#{MODAL} .ba-warning .btn-primary").click
          self
        end

        def filter(text)
          find("#{MODAL} .filter-input").fill_in(with: text)
          self
        end

        def select_scope(value)
          find("#{MODAL} .d-native-select").select(value)
          self
        end

        def toggle_only_loaded
          find("#{MODAL} .d-toggle-switch__checkbox").click
          self
        end

        def expand(name)
          find("#{MODAL} .ba-row .ba-label", text: name, match: :first).click
          self
        end

        def has_development_warning?
          page.has_css?("#{MODAL} .ba-warning")
        end

        def has_no_development_warning?
          page.has_no_css?("#{MODAL} .ba-warning")
        end

        def has_report?
          page.has_css?("#{MODAL} .bundle-analyzer")
        end

        def has_no_report?
          page.has_no_css?("#{MODAL} .bundle-analyzer")
        end

        def has_card?(name)
          page.has_css?("#{MODAL} .ba-row .ba-label", text: name)
        end

        def has_no_card?(name)
          page.has_no_css?("#{MODAL} .ba-row .ba-label", text: name)
        end

        # A build that did not compress has no brotli figure, so every row shows
        # a dash where the size would be.
        def has_unmeasured_sizes?
          page.has_css?("#{MODAL} .ba-num b", text: "—")
        end
      end
    end
  end
end
