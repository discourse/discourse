# frozen_string_literal: true

module PageObjects
  module Components
    class Composer < PageObjects::Components::Base
      COMPOSER_ID = "#reply-control"
      AUTOCOMPLETE_MENU = ".autocomplete.ac-emoji"
      HASHTAG_MENU = ".autocomplete.hashtag-autocomplete"
      MENTION_MENU = ".autocomplete.ac-user"
      RICH_EDITOR = ".d-editor-input.ProseMirror"
      POST_LANGUAGE_SELECTOR = ".post-language-selector"

      def rich_editor
        find(RICH_EDITOR)
      end

      def has_rich_editor?
        page.has_css?(RICH_EDITOR)
      end

      def has_no_rich_editor?
        page.has_no_css?(RICH_EDITOR)
      end

      def opened?
        page.has_css?("#{COMPOSER_ID}.open")
      end

      def closed?
        page.has_css?("#{COMPOSER_ID}.closed", visible: :all)
      end

      def minimized?
        page.has_css?("#{COMPOSER_ID}.draft")
      end

      def open_composer_actions
        find(".composer-action-title .btn").click
        self
      end

      def click_toolbar_button(button_class)
        find(".d-editor-button-bar button.#{button_class}").click
        self
      end

      def heading_menu
        PageObjects::Components::DMenu.new(find(".d-editor-button-bar button.heading"))
      end

      def focus
        find(COMPOSER_INPUT_SELECTOR).click
        self
      end

      def fill_title(title)
        find("#{COMPOSER_ID} #reply-title").fill_in(with: title)
        self
      end

      def fill_content(content)
        find("#{COMPOSER_ID} .d-editor .d-editor-input").fill_in(with: content)
        self
      end

      def minimize
        find("#{COMPOSER_ID} .toggle-minimize").click
        self
      end

      def append_content(content)
        current_content = composer_input.value
        composer_input.set(current_content + content)
        self
      end

      def fill_form_template_field(field, content)
        form_template_field(field).fill_in(with: content)
        self
      end

      def type_content(content)
        composer_input.send_keys(content)
        self
      end

      def clear_content
        fill_content("")
      end

      def has_content?(content)
        composer_input.value == content
      end

      def has_value?(value)
        try_until_success { expect(composer_input.value).to eq(value) }
      end

      def has_popup_content?(content)
        composer_popup.has_content?(content)
      end

      def select_action(action)
        find(action(action)).click
        self
      end

      def create
        find("#{COMPOSER_ID} .btn-primary").click
      end

      def action(action_title)
        ".composer-action-title .select-kit-collection li[title='#{action_title}']"
      end

      def button_label
        find("#{COMPOSER_ID} .btn-primary .d-button-label")
      end

      def emoji_picker
        find("#{COMPOSER_ID} .emoji-picker")
      end

      def emoji_autocomplete
        find(AUTOCOMPLETE_MENU)
      end

      def category_chooser
        Components::SelectKit.new(".category-chooser")
      end

      def locale
        find("#{COMPOSER_ID} #{POST_LANGUAGE_SELECTOR}")
      end

      def set_locale(locale)
        Components::DMenu.new(POST_LANGUAGE_SELECTOR).expand
        find("#{POST_LANGUAGE_SELECTOR} button", text: locale).click
      end

      def switch_category(category_name)
        category_chooser.expand
        category_chooser.select_row_by_name(category_name)
      end

      def preview
        find("#{COMPOSER_ID} .d-editor-preview-wrapper")
      end

      def has_discard_draft_modal?
        page.has_css?(".discard-draft-modal")
      end

      def has_hashtag_autocomplete?
        has_css?(HASHTAG_MENU)
      end

      def has_mention_autocomplete?
        has_css?(MENTION_MENU)
      end

      def mention_menu_autocomplete_username_list
        find(MENTION_MENU).all("a").map { |a| a.text }
      end

      def has_emoji_autocomplete?
        has_css?(AUTOCOMPLETE_MENU)
      end

      def has_no_emoji_autocomplete?
        has_no_css?(AUTOCOMPLETE_MENU)
      end

      EMOJI_SUGGESTION_SELECTOR = "#{AUTOCOMPLETE_MENU} .emoji-shortname"

      def has_emoji_suggestion?(emoji)
        has_css?(EMOJI_SUGGESTION_SELECTOR, text: emoji)
      end

      def has_no_emoji_suggestion?(emoji)
        has_no_css?(EMOJI_SUGGESTION_SELECTOR, text: emoji)
      end

      def has_emoji_preview?(emoji)
        page.has_css?(emoji_preview_selector(emoji))
      end

      def has_no_emoji_preview?(emoji)
        page.has_no_css?(emoji_preview_selector(emoji))
      end

      COMPOSER_INPUT_SELECTOR = "#{COMPOSER_ID} .d-editor-input"

      def has_no_composer_input?
        page.has_no_css?(COMPOSER_INPUT_SELECTOR)
      end

      def has_composer_input?
        page.has_css?(COMPOSER_INPUT_SELECTOR)
      end

      def has_composer_preview?
        page.has_css?("#{COMPOSER_ID} .d-editor-preview-wrapper")
      end

      def has_no_composer_preview?
        page.has_no_css?("#{COMPOSER_ID} .d-editor-preview-wrapper")
      end

      def has_composer_preview_toggle?
        page.has_css?("#{COMPOSER_ID} .toggle-preview")
      end

      def has_no_composer_preview_toggle?
        page.has_no_css?("#{COMPOSER_ID} .toggle-preview")
      end

      def has_form_template?
        page.has_css?(".form-template-form__wrapper")
      end

      def has_form_template_field?(field)
        page.has_css?(".form-template-field[data-field-type='#{field}']")
      end

      def has_form_template_field_required_indicator?(field)
        page.has_css?(
          ".form-template-field[data-field-type='#{field}'] .form-template-field__required-indicator",
        )
      end

      FORM_TEMPLATE_CHOOSER_SELECTOR = ".composer-select-form-template"

      def has_no_form_template_chooser?
        page.has_no_css?(FORM_TEMPLATE_CHOOSER_SELECTOR)
      end

      def has_form_template_chooser?
        page.has_css?(FORM_TEMPLATE_CHOOSER_SELECTOR)
      end

      def has_form_template_field_error?(error)
        page.has_css?(".form-template-field__error", text: error, visible: :all)
      end

      def has_no_form_template_field_error?(error)
        page.has_no_css?(".form-template-field__error", text: error, visible: :all)
      end

      def has_form_template_field_label?(label)
        page.has_css?(".form-template-field__label", text: label)
      end

      def has_form_template_field_description?(description)
        page.has_css?(".form-template-field__description", text: description)
      end

      def has_post_error?(error)
        page.has_css?(".popup-tip", text: error, visible: all)
      end

      def has_no_post_error?(error)
        page.has_no_css?(".popup-tip", text: error, visible: all)
      end

      def composer_input
        find("#{COMPOSER_ID} .d-editor .d-editor-input")
      end

      def composer_popup
        find("#{COMPOSER_ID} .composer-popup")
      end

      def form_template_field(field)
        find(".form-template-field[data-field-type='#{field}']")
      end

      def move_cursor_after(text)
        execute_script(<<~JS, text)
          const text = arguments[0];
          const composer = document.querySelector("#{COMPOSER_ID} .d-editor-input");
          const index = composer.value.indexOf(text);
          const position = index + text.length;

          composer.focus();
          composer.setSelectionRange(position, position);
        JS
      end

      def select_all
        find(COMPOSER_INPUT_SELECTOR).send_keys([PLATFORM_KEY_MODIFIER, "a"])
      end

      def select_range(start_index, length)
        execute_script(<<~JS, text)
          const composer = document.querySelector("#{COMPOSER_ID} .d-editor-input");
          composer.focus();
          composer.setSelectionRange(#{start_index}, #{length});
        JS
      end

      def select_range_rich_editor(start_index, length)
        focus
        select_text_range(RICH_EDITOR, start_index, length)
      end

      def submit
        find("#{COMPOSER_ID} .save-or-cancel .create").click
      end

      def close
        find("#{COMPOSER_ID} .save-or-cancel .cancel").click
      end

      def has_no_in_progress_uploads?
        find("#{COMPOSER_ID}").has_no_css?("#file-uploading")
      end

      def has_in_progress_uploads?
        find("#{COMPOSER_ID}").has_css?("#file-uploading")
      end

      def select_pm_user(username)
        select_kit = PageObjects::Components::SelectKit.new("#private-message-users")
        select_kit.expand
        select_kit.search(username)
        select_kit.select_row_by_value(username)
        select_kit.collapse
      end

      def has_rich_editor_active?
        find("#{COMPOSER_ID}").has_css?(".composer-toggle-switch.--rte")
      end

      def has_no_rich_editor_active?
        find("#{COMPOSER_ID}").has_css?(".composer-toggle-switch.--markdown")
      end

      def has_markdown_editor_active?
        has_no_rich_editor_active?
      end

      def toggle_rich_editor
        rich = page.find(".composer-toggle-switch")["data-rich-editor"]

        editor_toggle_switch.click

        if rich
          has_no_rich_editor_active?
        else
          has_rich_editor_active?
        end

        self
      end

      def editor_toggle_switch
        find("#{COMPOSER_ID} .composer-toggle-switch")
      end

      private

      def emoji_preview_selector(emoji)
        ".d-editor-preview .emoji[title=':#{emoji}:']"
      end
    end
  end
end
