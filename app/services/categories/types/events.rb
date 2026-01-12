# frozen_string_literal: true

module Categories
  module Types
    class Events < Base
      class << self
        def available?
          defined?(DiscourseCalendar) && SiteSetting.respond_to?(:calendar_enabled)
        end

        def enable_plugin
          SiteSetting.calendar_enabled = true
          SiteSetting.discourse_post_event_enabled = true

          # Ensure at least staff can create events if no groups are configured
          if SiteSetting.discourse_post_event_allowed_on_groups.blank?
            SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:staff].to_s
          end
        end

        def configure_site_settings(category)
          add_to_setting_list(:events_calendar_categories, category.id)
        end

        def configure_category(category)
          category.custom_fields["sort_topics_by_event_start_date"] = true
          category.save_custom_fields
        end

        def icon
          "calendar-days"
        end
      end
    end
  end
end
