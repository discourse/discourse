# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class BundleAnalyzer < PageObjects::Components::Base
        MODAL = ".bundle-analyzer-modal"

        # The warning renders with the modal, so a production build — which has
        # nothing to warn about — is known immediately rather than waited for.
        def dismiss_development_warning
          if page.has_css?("#{MODAL} .ba-warning", wait: 0)
            find("#{MODAL} .ba-warning .btn-primary").click
          end
          self
        end

        def filter(text)
          find("#{MODAL} .filter-input").fill_in(with: text)
          self
        end

        def filter_text
          find("#{MODAL} .filter-input").value
        end

        def select_scope(value)
          PageObjects::Components::DNativeSelect.new("#{MODAL} .d-native-select").select(value)
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

        def toggle_card(name)
          find("#{MODAL} .ba-row .ba-label", exact_text: name).click
          self
        end

        def has_expanded_card?(name)
          page.has_css?("#{MODAL} .ba-row.open > .ba-head .ba-label", exact_text: name)
        end

        def has_no_expanded_card?(name)
          page.has_no_css?("#{MODAL} .ba-row.open > .ba-head .ba-label", exact_text: name)
        end

        def has_card?(name)
          page.has_css?("#{MODAL} .ba-row .ba-label", exact_text: name)
        end

        def has_no_card?(name)
          page.has_no_css?("#{MODAL} .ba-row .ba-label", exact_text: name)
        end

        # A build that did not compress shows a dash where each size would be.
        def has_unmeasured_sizes?
          page.has_css?("#{MODAL} .ba-num b", text: "—")
        end
      end
    end
  end
end
