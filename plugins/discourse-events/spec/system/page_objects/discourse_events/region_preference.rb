# frozen_string_literal: true

module PageObjects
  module Components
    module DiscourseEvents
      class RegionPreference < PageObjects::Components::Base
        SELECTOR = ".control-group.region"

        def notice
          PageObjects::Components::AccessNotice.new(SELECTOR)
        end

        def has_use_current_region_disabled?
          has_css?("#{SELECTOR} .btn[disabled]", text: use_current_region)
        end

        def has_use_current_region_enabled?
          has_css?("#{SELECTOR} .btn:not([disabled])", text: use_current_region)
        end

        private

        def use_current_region
          I18n.t("js.discourse_events.region.use_current_region")
        end
      end
    end
  end
end
