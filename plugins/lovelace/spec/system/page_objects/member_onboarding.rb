# frozen_string_literal: true

module PageObjects
  module Pages
    class LovelaceMemberOnboarding < Base
      def open
        visit("/admin/plugins/lovelace/member-onboarding")
        self
      end

      def add_suggestion(title)
        within(".lovelace-onboarding__suggestion", text: title) { click_button("Add", exact: true) }
      end

      def has_bank_item?(title)
        has_css?(".lovelace-onboarding__suggestion", text: title)
      end

      def has_no_bank_item?(title)
        has_no_css?(".lovelace-onboarding__suggestion", text: title)
      end

      def has_empty_bank?
        has_css?(".lovelace-onboarding__bank", text: I18n.t("js.lovelace.bank_empty"))
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
        has_css?(".lovelace-onboarding__items .lovelace-onboarding__item", text: title) &&
          has_no_css?(".lovelace-onboarding__editor")
      end

      def has_checklist_row?(title, description)
        has_css?(".lovelace-onboarding__items .lovelace-onboarding__row", text: title) do |row|
          row.has_css?("strong", text: title) && row.has_css?("p", text: description) &&
            row.has_button?("Edit") && row.has_css?(".d-reorderable-list__handle") &&
            row.has_css?(".d-reorderable-list__remove") && row.has_no_css?("input[type='checkbox']")
        end
      end

      def has_preview_row?(title, description, button, path)
        has_css?(".lovelace-onboarding__preview-item", text: title) do |row|
          row.has_css?("strong", text: title) && row.has_css?("p", text: description) &&
            row.has_field?(title, type: "checkbox") && row.has_link?(button, href: path) &&
            row.has_no_button?("Edit") &&
            row.has_no_css?(".d-reorderable-list__handle, .d-reorderable-list__remove")
        end
      end

      def has_bank_row?(title, description)
        has_css?(".lovelace-onboarding__suggestion", text: title) do |row|
          row.has_css?("strong", text: title) && row.has_css?("p", text: description) &&
            row.has_button?("Add", exact: true) && row.has_no_button?("Edit") &&
            row.has_no_css?(
              "input[type='checkbox'], .d-reorderable-list__handle, .d-reorderable-list__remove",
            )
        end
      end

      def has_grouped_configuration?(stacked:)
        has_css?(".lovelace-onboarding__configuration") do |configuration|
          configuration.evaluate_script(<<~JS)
            (() => {
              const items = this.querySelector('.lovelace-onboarding__items').getBoundingClientRect();
              const bank = this.querySelector('.lovelace-onboarding__bank').getBoundingClientRect();
              const preview = document.querySelector('.lovelace-onboarding__preview').getBoundingClientRect();
              const adjacent = Math.abs(items.left - bank.left) < 1 && bank.top >= items.bottom && bank.top - items.bottom < 24;
              const previewPosition = #{stacked} ? preview.top >= bank.bottom : preview.left >= items.right;
              return adjacent && previewPosition && document.documentElement.scrollWidth <= window.innerWidth;
            })()
          JS
        end
      end

      def preview_clear(title)
        within(".lovelace-onboarding__preview") { uncheck(title) }
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
        has_no_css?(".lovelace-onboarding__items .lovelace-onboarding__item", text: title)
      end
    end
  end
end
