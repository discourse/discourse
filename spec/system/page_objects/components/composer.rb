# frozen_string_literal: true

module PageObjects
  module Components
    class Composer < PageObjects::Components::Base
      COMPOSER_ID = "#reply-control"
      AUTOCOMPLETE_MENU = ".autocomplete.ac-emoji"
      HASHTAG_MENU = ".autocomplete.hashtag-autocomplete"
      MENTION_MENU = ".autocomplete.ac-user"
      RICH_EDITOR = ".d-editor-input.ProseMirror"
      POST_LANGUAGE_SELECTOR = ".post-language-selector-trigger"

      def initialize(composer_id = COMPOSER_ID)
        @composer_id = composer_id
      end

      def rich_editor
        browser_root.locator(RICH_EDITOR).filter(visible: true)
      end

      def has_rich_editor?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(RICH_EDITOR).filter(visible: true),
        )
      end

      def has_no_rich_editor?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(RICH_EDITOR).filter(visible: true),
        )
      end

      def has_no_animated_images?
        result =
          browser_page.wait_for_function(
            <<~JS,
          selector => Array.from(document.querySelectorAll(selector))
            .filter(image => image.getClientRects().length && getComputedStyle(image).visibility !== "hidden")
            .every(image => getComputedStyle(image).animationName === "none")
        JS
            arg: "#{RICH_EDITOR} .composer-image-node img",
            timeout: Capybara.default_max_wait_time * 1000,
          )
        result.dispose
        true
      end

      def opened?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id}.open").filter(visible: true),
        )
      end

      def closed?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id}.closed"),
        )
      end

      def minimized?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id}.draft").filter(visible: true),
        )
      end

      def open_composer_actions
        browser_root.locator(".composer-actions-trigger").filter(visible: true).click
        self
      end

      def click_toolbar_button(button_class)
        browser_root
          .locator(".d-editor-button-bar button.#{button_class}")
          .filter(visible: true)
          .click
        self
      end

      def heading_menu
        PageObjects::Components::DMenu.new(
          browser_root.locator(".d-editor-button-bar button.heading").filter(visible: true),
        )
      end

      def list_menu
        PageObjects::Components::DMenu.new(
          browser_root.locator(".d-editor-button-bar button.list").filter(visible: true),
        )
      end

      def focus
        browser_root.locator(composer_input_selector).filter(visible: true).click
        self
      end

      def height
        browser_root.locator(@composer_id).filter(visible: true).bounding_box["height"].round
      end

      def drag_resize_by(pixels)
        drag_with_pointer(from: "#{@composer_id} .grippie", by: { y: -pixels })
        self
      end

      # The composer's height is driven by this variable, so matching it is how the
      # resize is observed. Named for what it reads rather than for the height, which
      # would suggest measuring the box.
      def has_applied_height?(height)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("html[style*='--composer-height: #{height}px']"),
        )
      end

      def fill_title(title)
        browser_root.locator("#{@composer_id} #reply-title").filter(visible: true).fill(title)
        self
      end

      def has_input_title?(value)
        PlaywrightMatchers.have_value(
          (
            if value.is_a?(Regexp)
              Regexp.new(value.source.gsub('\A', "^").gsub('\z', "$"), value.options)
            else
              value
            end
          ),
        ).matches?(
          browser_root
            .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
            .and(
              browser_root.locator(
                "[id=#{"reply-title".to_s.to_json}], [name=#{"reply-title".to_s.to_json}]",
              ).or(browser_root.get_by_label("reply-title", exact: true)),
            )
            .filter(visible: true),
        )
      end

      # Methods for when the enable_composer_redesign upcoming change is enabled.

      def has_footer_toolbar?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{@composer_id} .composer-footer__toolbar .d-editor-button-bar",
          ).filter(visible: true),
        )
      end

      def has_title_below_category_row?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id} .title-and-category ~ .title-input").filter(
            visible: true,
          ),
        )
      end

      def has_pm_recipients_in_category_row?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id} .title-and-category .user-selector").filter(
            visible: true,
          ),
        )
      end

      def has_toggle_toolbar_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id} .toggle-toolbar").filter(visible: true),
        )
      end

      # Methods for when the enable_composer_redesign upcoming change is disabled.

      def has_no_footer_toolbar?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{@composer_id} .composer-footer").filter(visible: true),
        )
      end

      def has_inline_toolbar?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{@composer_id} .d-editor-textarea-wrapper .d-editor-button-bar",
          ).filter(visible: true),
        )
      end

      def has_title_in_category_row?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id} .title-and-category .title-input").filter(
            visible: true,
          ),
        )
      end

      def toggle_toolbar
        browser_root.locator("#{@composer_id} .toggle-toolbar").filter(visible: true).click
        self
      end

      def has_visible_toolbar?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id} .d-editor-button-bar").filter(visible: true),
        )
      end

      def has_no_visible_toolbar?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{@composer_id} .d-editor-button-bar").filter(visible: true),
        )
      end

      def fill_content(content)
        browser_root
          .locator("#{@composer_id} .d-editor .d-editor-input")
          .filter(visible: true)
          .fill(content)
        self
      end

      def minimize
        browser_root.locator("#{@composer_id} .toggle-minimize").filter(visible: true).click
        self
      end

      def append_content(content)
        current_content = composer_input.input_value
        composer_input.fill(current_content + content)
        self
      end

      def fill_form_template_field(field, content)
        form_template_field(field)
          .locator("input:not([aria-hidden=true]), textarea:not([aria-hidden=true])")
          .filter(visible: true)
          .fill(content.to_s)
        self
      end

      def type_content(content)
        if content.is_a?(Symbol)
          composer_input.press(browser_key_chord([content]))
        elsif content.is_a?(Array)
          composer_input.press(browser_key_chord(content))
        else
          composer_input.press_sequentially(content)
        end
        self
      end

      def clear_content
        fill_content("")
      end

      def has_displayed_content?(content)
        composer_input.input_value == content
      end

      def has_value?(value)
        within_browser(@composer_id) do
          if value.nil?
            PlaywrightMatchers.have_count(0).matches?(
              browser_root
                .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
                .and(browser_root.locator(".#{"d-editor-input".to_s.split.join(".")}"))
                .filter(visible: true),
            )
          else
            PlaywrightMatchers.have_value(
              (
                if value.is_a?(Regexp)
                  Regexp.new(value.source.gsub('\A', "^").gsub('\z', "$"), value.options)
                else
                  value
                end
              ),
            ).matches?(
              browser_root
                .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
                .and(browser_root.locator(".#{"d-editor-input".to_s.split.join(".")}"))
                .filter(visible: true),
            )
          end
        end
      end

      def has_popup_content?(content)
        PlaywrightMatchers.contain_text(browser_text_pattern(content), useInnerText: true).matches?(
          composer_popup,
        )
      end

      def has_no_action?(action)
        !actions.include?(action)
      end

      def has_no_action_id?(action_id)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".composer-actions-dropdown [data-action-id='#{action_id}']").filter(
            visible: true,
          ),
        )
      end

      def select_action(action)
        browser_root.locator(action(action)).filter(visible: true).click
        self
      end

      def select_action_by_id(action_id)
        browser_root
          .locator(".composer-actions-dropdown [data-action-id='#{action_id}']")
          .filter(visible: true)
          .click
        self
      end

      def reply_button_focused?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id} .btn-primary:focus").filter(visible: true),
        )
      end

      def create
        browser_root.locator("#{@composer_id} .btn-primary").filter(visible: true).click
      end

      def action(action_title)
        ".composer-action-title .select-kit-collection li[title='#{action_title}']"
      end

      def actions
        browser_root
          .locator(".composer-action-title .select-kit-collection li")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map do |el|
            el.evaluate(
              "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
              arg: "title",
            )
          end
      end

      def button_label
        browser_root.locator("#{@composer_id} .btn-primary .d-button-label").filter(visible: true)
      end

      def emoji_picker
        browser_root.locator("#{@composer_id} .emoji-picker").filter(visible: true)
      end

      def emoji_autocomplete
        browser_root.locator(AUTOCOMPLETE_MENU).filter(visible: true)
      end

      def category_chooser
        Components::SelectKit.new(".category-chooser")
      end

      def locale
        browser_root.locator(
          "#{@composer_id} .d-editor-button-bar #{POST_LANGUAGE_SELECTOR}",
        ).filter(visible: true)
      end

      def set_locale(locale)
        click_toolbar_button("post-language-selector-trigger")
        within_browser(browser_root.locator("#d-menu-portals"), wait_state: "attached") do
          browser_root
            .locator("button")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(locale))
            .click
        end
      end

      def switch_category(category_name)
        category_chooser.expand
        category_chooser.select_row_by_name(category_name)
      end

      def preview
        browser_root.locator("#{@composer_id} .d-editor-preview-wrapper").filter(visible: true)
      end

      def has_discard_draft_modal?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".discard-draft-modal").filter(visible: true),
        )
      end

      def has_hashtag_autocomplete?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(HASHTAG_MENU).filter(visible: true),
        )
      end

      def has_mention_autocomplete?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(MENTION_MENU).filter(visible: true),
        )
      end

      def mention_menu_autocomplete_username_list
        browser_root
          .locator(MENTION_MENU)
          .filter(visible: true)
          .locator("a")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |a| a.inner_text.strip }
      end

      def has_emoji_autocomplete?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(AUTOCOMPLETE_MENU).filter(visible: true),
        )
      end

      def has_no_emoji_autocomplete?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(AUTOCOMPLETE_MENU).filter(visible: true),
        )
      end

      def has_emoji_autocomplete_selected?(index)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{AUTOCOMPLETE_MENU} ul li:nth-child(#{index}) a.selected").filter(
            visible: true,
          ),
        )
      end

      EMOJI_SUGGESTION_SELECTOR = "#{AUTOCOMPLETE_MENU} .emoji-shortname"

      def has_emoji_suggestion?(emoji)
        PlaywrightMatchers.contain_text([browser_text_pattern(emoji)], useInnerText: true).matches?(
          browser_root.locator(EMOJI_SUGGESTION_SELECTOR).filter(visible: true),
        )
      end

      def has_no_emoji_suggestion?(emoji)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(emoji)],
          useInnerText: true,
        ).does_not_match?(browser_root.locator(EMOJI_SUGGESTION_SELECTOR).filter(visible: true))
      end

      def has_emoji_preview?(emoji)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(emoji_preview_selector(emoji)).filter(visible: true),
        )
      end

      def has_no_emoji_preview?(emoji)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(emoji_preview_selector(emoji)).filter(visible: true),
        )
      end

      def composer_input_selector
        "#{@composer_id} .d-editor-input"
      end

      def has_no_composer_input?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(composer_input_selector).filter(visible: true),
        )
      end

      def has_composer_input?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(composer_input_selector).filter(visible: true),
        )
      end

      def has_composer_preview?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id} .d-editor-preview-wrapper").filter(visible: true),
        )
      end

      def has_no_composer_preview?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{@composer_id} .d-editor-preview-wrapper").filter(visible: true),
        )
      end

      def has_composer_preview_toggle?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id} .toggle-preview").filter(visible: true),
        )
      end

      def has_no_composer_preview_toggle?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{@composer_id} .toggle-preview").filter(visible: true),
        )
      end

      def has_form_template?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".form-template-form__wrapper").filter(visible: true),
        )
      end

      def has_form_template_field?(field)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".form-template-field[data-field-type='#{field}']").filter(
            visible: true,
          ),
        )
      end

      def has_form_template_field_required_indicator?(field)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".form-template-field[data-field-type='#{field}'] .form-template-field__required-indicator",
          ).filter(visible: true),
        )
      end

      FORM_TEMPLATE_CHOOSER_SELECTOR = ".composer-select-form-template"

      def has_no_form_template_chooser?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(FORM_TEMPLATE_CHOOSER_SELECTOR).filter(visible: true),
        )
      end

      def has_form_template_chooser?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(FORM_TEMPLATE_CHOOSER_SELECTOR).filter(visible: true),
        )
      end

      def has_form_template_field_error?(error)
        PlaywrightMatchers.contain_text([browser_text_pattern(error)], useInnerText: true).matches?(
          browser_root.locator(".form-template-field__error"),
        )
      end

      def has_no_form_template_field_error?(error)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(error)],
          useInnerText: true,
        ).does_not_match?(browser_root.locator(".form-template-field__error"))
      end

      def has_form_template_field_label?(label)
        PlaywrightMatchers.contain_text([browser_text_pattern(label)], useInnerText: true).matches?(
          browser_root.locator(".form-template-field__label").filter(visible: true),
        )
      end

      def has_form_template_field_description?(description)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(description)],
          useInnerText: true,
        ).matches?(browser_root.locator(".form-template-field__description").filter(visible: true))
      end

      def has_post_error?(error)
        PlaywrightMatchers.contain_text([error]).matches?(browser_page.locator(".popup-tip"))
      end

      def has_no_post_error?(error)
        PlaywrightMatchers.contain_text([error]).does_not_match?(browser_page.locator(".popup-tip"))
      end

      def composer_input
        browser_root.locator("#{@composer_id} .d-editor-input").filter(visible: true)
      end

      def composer_popup
        browser_root.locator("#{@composer_id} .composer-popup").filter(visible: true)
      end

      def form_template_field(field)
        browser_root.locator(".form-template-field[data-field-type='#{field}']").filter(
          visible: true,
        )
      end

      def move_cursor_after(text)
        browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: browser_arguments(text))
          const text = arguments[0];
          const composer = document.querySelector("#{@composer_id} .d-editor-input");
          const index = composer.value.indexOf(text);
          const position = index + text.length;

          composer.focus();
          composer.setSelectionRange(position, position);
        JS
      end

      def select_all
        browser_root
          .locator(composer_input_selector)
          .filter(visible: true)
          .press(
            [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "a"].join("+"),
          )
      end

      def select_range(start_index, length)
        browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: browser_arguments(text))
          const composer = document.querySelector("#{@composer_id} .d-editor-input");
          composer.focus();
          composer.setSelectionRange(#{start_index}, #{length});
        JS
      end

      def select_range_rich_editor(start_index, length)
        focus
        select_text_range(RICH_EDITOR, start_index, length)
      end

      def select_code_block
        select_all_content("#{RICH_EDITOR} pre code")
      end

      def has_nested_list_item?(text)
        PlaywrightMatchers.contain_text(
          [browser_exact_text_pattern(text)],
          useInnerText: true,
        ).matches?(browser_root.locator("#{RICH_EDITOR} li > ul > li").filter(visible: true))
      end

      def has_top_level_list_item?(text)
        PlaywrightMatchers.contain_text(
          [browser_exact_text_pattern(text)],
          useInnerText: true,
        ).matches?(browser_root.locator("#{RICH_EDITOR} > ul > li").filter(visible: true))
      end

      def submit
        browser_root.locator("#{@composer_id} .save-or-cancel .create").filter(visible: true).click
      end

      def discard
        browser_root.locator("#{@composer_id} .discard-button").filter(visible: true).click
      end

      def close
        browser_root.locator("#{@composer_id} .toggle-save-and-close").filter(visible: true).click
      end

      def has_no_in_progress_uploads?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root
            .locator("#{@composer_id}")
            .filter(visible: true)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator("#file-uploading")
            .filter(visible: true),
        )
      end

      def has_in_progress_uploads?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .locator("#{@composer_id}")
            .filter(visible: true)
            .locator("#file-uploading")
            .filter(visible: true),
        )
      end

      def select_pm_user(username)
        select_kit = PageObjects::Components::SelectKit.new("#private-message-users")
        select_kit.expand
        select_kit.search(username)
        select_kit.select_row_by_value(username)
        select_kit.collapse
      end

      def has_rich_editor_active?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .locator("#{@composer_id}")
            .filter(visible: true)
            .locator(".d-editor-container.--rich-editor-enabled")
            .filter(visible: true),
        )
      end

      def has_no_rich_editor_active?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .locator("#{@composer_id}")
            .filter(visible: true)
            .locator(".d-editor-container.--markdown-editor-enabled")
            .filter(visible: true),
        )
      end

      def has_markdown_editor_active?
        has_no_rich_editor_active?
      end

      def toggle_rich_editor
        rich =
          browser_root
            .locator(".composer-toggle-switch")
            .filter(visible: true)
            .get_attribute("data-rich-editor")

        editor_toggle_switch.click

        if rich
          has_no_rich_editor_active?
        else
          has_rich_editor_active?
        end

        self
      end

      def has_toggle_switch?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{@composer_id} .composer-toggle-switch").filter(visible: true),
        )
      end

      def has_no_toggle_switch?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{@composer_id} .composer-toggle-switch").filter(visible: true),
        )
      end

      def editor_toggle_switch
        browser_root.locator("#{@composer_id} .composer-toggle-switch").filter(visible: true)
      end

      def image_grid
        Components::ComposerImageGrid.new(rich_editor)
      end

      private

      def emoji_preview_selector(emoji)
        ".d-editor-preview .emoji[title=':#{emoji}:']"
      end
    end
  end
end
