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
        if has_css?(".d-page-subheader [data-trigger]", wait: 0)
          find(".d-page-subheader [data-trigger]").click
        end
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
        has_css?(
          ".lovelace-onboarding__preview .lovelace-member-checklist__item",
          text: title,
        ) do |row|
          row.has_css?("strong", text: title) && row.has_css?("p", text: description) &&
            row.has_button?(title, exact: true) && row.has_link?(button, href: path) &&
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
              const adjacent = #{stacked} ? Math.abs(items.left - bank.left) < 1 && bank.top >= items.bottom : bank.left >= items.right && Math.abs(items.top - bank.top) < 1;
              const previewPosition = preview.top >= Math.max(items.bottom, bank.bottom) && preview.width >= this.getBoundingClientRect().width - 2;
              return adjacent && previewPosition && document.documentElement.scrollWidth <= window.innerWidth;
            })()
          JS
        end
      end

      def preview_clear(title)
        within(".lovelace-onboarding__preview") { click_button(title, exact: true) }
      end

      def preview_complete(title)
        within(".lovelace-onboarding__preview") { click_button(title, exact: true) }
      end

      def has_progress?(text)
        has_css?(".lovelace-onboarding__preview .lovelace-member-checklist__progress", text: text)
      end

      def has_preview_link?(path)
        has_css?(
          ".lovelace-onboarding__preview a[href='#{path}'][target='_blank'][rel='noopener noreferrer']",
        )
      end

      def cancel_editor
        within(".lovelace-onboarding-editor") { click_button("Cancel", exact: true) }
      end

      def close_editor_with_escape
        find(".lovelace-onboarding-editor input[name='title']").send_keys(:escape)
      end

      def has_responsive_editor?
        has_css?(".lovelace-onboarding-editor .d-modal__container") do |modal|
          modal.evaluate_script(<<~JS)
            (() => {
              const modal = this.getBoundingClientRect();
              return modal.left >= 0 && modal.right <= window.innerWidth && [...this.querySelectorAll('input, textarea, select')].every(control => control.getBoundingClientRect().right <= modal.right);
            })()
          JS
        end
      end

      def has_item_modal?(title)
        has_css?(".lovelace-onboarding-editor .d-modal__title", text: title) &&
          has_button?("Save item", exact: true) &&
          has_no_css?(".lovelace-onboarding__items .lovelace-onboarding__editor")
      end

      def has_destination_field?(label)
        has_css?(
          ".lovelace-onboarding__editor .form-kit__field label",
          text: label,
          exact_text: true,
        ) && has_no_css?(".lovelace-onboarding__editor input[name='url']") &&
          has_no_css?(".lovelace-onboarding__editor .form-kit__help")
      end

      def destination_chooser
        PageObjects::Components::SelectKit.new(".lovelace-onboarding__editor .select-kit")
      end

      def choose_destination(name)
        search_destination(name)
        select_destination(name)
      end

      def search_destination(name)
        destination_chooser.expand
        destination_chooser.search(name)
      end

      def select_destination(name)
        destination_chooser.select_row_by_name(name)
      end

      def has_channel_option?(channel)
        has_css?(".lovelace-channel-chooser .select-kit-row", text: channel.name) do |row|
          row.has_css?(".d-icon-d-chat")
        end
      end

      def has_selected_channel?(channel)
        has_css?(".lovelace-channel-chooser .select-kit-header", text: channel.name) do |header|
          header.has_css?(".d-icon-d-chat")
        end
      end

      def has_selected_destination?(name)
        has_css?(".lovelace-onboarding__editor .select-kit-header", text: name)
      end

      def has_destination_error?
        has_css?(".lovelace-onboarding__editor .form-kit__errors")
      end

      def reset_preview
        click_button("Reset preview")
      end

      def minimize_preview
        within(".lovelace-onboarding__preview") { click_button("Minimize", exact: true) }
      end

      def expand_preview
        within(".lovelace-onboarding__preview") { click_button("Expand", exact: true) }
      end

      def dismiss_preview
        within(".lovelace-onboarding__preview") { click_button("Dismiss checklist", exact: true) }
      end

      def has_no_preview?
        has_no_css?(".lovelace-onboarding__preview .lovelace-member-checklist")
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
