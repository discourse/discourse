# frozen_string_literal: true

module PageObjects
  module Pages
    class LovelaceMemberOnboarding < Base
      def open
        visit("/admin/plugins/lovelace/member-onboarding")
        self
      end

      def editor
        PageObjects::Components::FormKit.new(".lovelace-onboarding__editor")
      end

      def start_item
        click_button("Add checklist item")
      end

      def add_item(title, destination: :profile)
        start_item
        editor.field("title").fill_in(title)
        editor.field("description").fill_in("Welcome to the community.")
        editor.field("link_type").select(destination.to_s)
        editor.field("button_text").fill_in("Get started")
        editor.submit
      end

      def edit_item(title)
        within(".d-reorderable-list__row", text: title) { click_button("Edit") }
      end

      def has_saved_item?(title)
        has_css?(".lovelace-onboarding__item", text: title) &&
          has_no_css?(".lovelace-onboarding__editor")
      end

      def preview_complete(title)
        within(".lovelace-onboarding__preview") { check(title) }
      end

      def has_progress?(text)
        has_css?(".lovelace-onboarding__progress", text: text)
      end

      def has_preview_link?(path)
        has_css?(
          ".lovelace-onboarding__preview a[href='#{path}'][target='_blank'][rel='noopener noreferrer']",
        )
      end

      def go_to_settings
        click_link("Settings", exact: true)
      end

      def has_order?(titles)
        titles.each_with_index.all? do |title, index|
          has_css?(".d-reorderable-list__row:nth-child(#{index + 1})", text: title)
        end
      end

      def move_first_down
        find(".d-reorderable-list__row:first-child .d-reorderable-list__handle").send_keys(
          %i[alt down],
        )
      end

      def drag_last_to_top
        drag_and_drop(
          source: ".d-reorderable-list__row:last-child .d-reorderable-list__handle",
          target: ".d-reorderable-list__row:first-child",
          target_position: {
            x: 100,
            y: 1,
          },
        )
      end

      def remove_item(title)
        within(".d-reorderable-list__row", text: title) do
          find(".d-reorderable-list__remove").click
        end
      end

      def has_no_item?(title)
        has_no_css?(".lovelace-onboarding__item", text: title)
      end
    end
  end
end
