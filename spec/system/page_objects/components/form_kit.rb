# frozen_string_literal: true

module PageObjects
  module Components
    class FormKitContainer < PageObjects::Components::Base
      attr_reader :component

      def initialize(input)
        if input.is_a?(Playwright::Locator)
          @component = input
        else
          @component = browser_root.locator(input).filter(visible: true)
        end
      end

      def has_displayed_content?(content)
        contain_text(browser_text_pattern(content), useInnerText: true).matches?(component)
      end
    end

    class FormKitField < PageObjects::Components::Base
      attr_reader :component

      def initialize(input)
        if input.is_a?(Playwright::Locator)
          @component = input
        else
          @component = browser_root.locator(input).filter(visible: true)
        end
      end

      def value
        case control_type
        when "input", /input-/, "password"
          component.locator("input").filter(visible: true).input_value
        when "color"
          component.locator("input[type='text']").filter(visible: true).input_value
        when "icon"
          PageObjects::Components::DIconGridPicker.new(component).value
        when "multi-select"
          picker = PageObjects::Components::SelectKit.new(component)
          picker.value
        when "tag-chooser"
          picker = PageObjects::Components::SelectKit.new(tag_chooser_selector)
          picker.value
        when "checkbox"
          component.locator("input[type='checkbox']").checked?
        when "menu"
          component.locator(".fk-d-menu__trigger").filter(visible: true).get_attribute("data-value")
        when "select"
          PageObjects::Components::DNativeSelect.new(
            component.locator("select").filter(visible: true),
          ).value
        when "radio-group"
          component.locator("input[type='radio']:checked").input_value
        when "composer", "textarea"
          component.locator("textarea").filter(visible: true).input_value
        when "image"
          url =
            component
              .locator(".file-uploader__preview a.lightbox")
              .filter(visible: true)
              .evaluate(
                "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
                arg: "href",
              )
          sha1 = url.match(/(\h{40})/).captures.first
          Upload.find_by(sha1:)
        when "toggle"
          component.locator("button[role=\"switch\"]").get_attribute("aria-checked") == "true"
        end
      end

      def uncheck
        if control_type == "checkbox"
          return unless value

          component.locator(".form-kit__control-checkbox-checkmark").filter(visible: true).click
        end
      end

      def check
        if control_type == "checkbox"
          return if value

          component.locator(".form-kit__control-checkbox-checkmark").filter(visible: true).click
        end
      end

      def unchecked?
        if control_type != "checkbox"
          raise "'unchecked?' is only supported for control type: #{control_type}"
        end

        expect(value).to eq(false)
      end

      def checked?
        if control_type != "checkbox"
          raise "'checked?' is only supported for control type: #{control_type}"
        end

        expect(value).to eq(true)
      end

      def has_value?(expected_value)
        expect(value).to eq(expected_value)
      end

      def has_errors?(*messages)
        within_browser(component) do
          messages.all? do |m|
            have_count(0).does_not_match?(
              browser_root
                .locator(".form-kit__errors")
                .filter(visible: true)
                .filter(hasText: browser_text_pattern(m)),
            )
          end
        end
      end

      def has_no_errors?
        have_count(0).matches?(browser_root.locator(".form-kit__errors").filter(visible: true))
      end

      def control_type
        type = component.get_attribute("data-control-type")

        return type if type != "custom"

        if have_count(0).does_not_match?(component.locator(".multi-select").filter(visible: true))
          "multi-select"
        elsif have_count(0).does_not_match?(component.locator("textarea").filter(visible: true))
          "textarea"
        else
          raise "Unknown custom control"
        end
      end

      def toggle
        case control_type
        when "checkbox"
          component.locator(".form-kit__control-checkbox-checkmark").filter(visible: true).click
        when "password"
          component.locator(".form-kit__control-password-toggle").filter(visible: true).click
        when "toggle"
          component
            .locator("button[role=\"switch\"]")
            .locator("xpath=ancestor::*")
            .and(browser_page.locator("label"))
            .last
            .click
        else
          raise "'toggle' is not supported for control type: #{control_type}"
        end
      end

      def fill_in(value)
        case control_type
        when "input", /input-/, "password"
          component.locator("input").filter(visible: true).fill(value)
        when "color"
          component.locator("input[type='text']").filter(visible: true).fill(value)
        when "textarea", "composer"
          component.locator("textarea").filter(visible: true).fill(value)
        when "code"
          component.locator(".ace_text-input").fill(value)
        else
          raise "Unsupported control type: #{control_type}"
        end
      end

      def select(value)
        case control_type
        when "icon"
          picker = PageObjects::Components::DIconGridPicker.new(component)
          picker.expand
          picker.select_icon(value)
        when "multi-select"
          selector =
            component
              .locator(".form-kit__control-custom > .multi-select")
              .filter(visible: true)
              .evaluate(
                "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
                arg: "id",
              )
          picker = PageObjects::Components::SelectKit.new("#" + selector)
          picker.expand
          picker.search(value)
          picker.select_row_by_name(value)
          picker.collapse
        when "tag-chooser"
          picker = PageObjects::Components::SelectKit.new(tag_chooser_selector)
          picker.expand
          picker.search(value)
          picker.select_row_by_name(value)
          picker.collapse
        when "select"
          PageObjects::Components::DNativeSelect.new(
            component.locator(".form-kit__control-select").filter(visible: true),
          ).select(value)
        when "menu"
          trigger =
            component.locator(".fk-d-menu__trigger.form-kit__control-menu-trigger").filter(
              visible: true,
            )
          trigger.click
          menu =
            browser_root.locator(
              "[aria-labelledby='#{trigger.evaluate("(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }", arg: "id")}']",
            ).filter(visible: true)
          item =
            menu.locator(".form-kit__control-menu-item[data-value='#{value}'] .btn").filter(
              visible: true,
            )
          item.click
        when "radio-group"
          radio = component.locator("input[type='radio'][value='#{value}']").filter(visible: true)
          radio.click
        when "question"
          value == true ? accept : refuse
        else
          raise "Unsupported control type: #{control_type}"
        end
      end

      def select_none
        select(PageObjects::Components::DNativeSelect::NO_VALUE_OPTION)
      end

      def has_no_value?
        if control_type == "select"
          PageObjects::Components::DNativeSelect.new(
            component.locator(".form-kit__control-select").filter(visible: true),
          ).has_no_value?
        else
          raise "'has_no_value?' is not supported for control type: #{control_type}"
        end
      end

      def accept
        if control_type == "question"
          component.locator(".form-kit__control-radio[value='true']").filter(visible: true).click
        else
          raise "'accept' is not supported for control type: #{control_type}"
        end
      end

      def refuse
        if control_type == "question"
          component.locator(".form-kit__control-radio[value='false']").filter(visible: true).click
        else
          raise "'refuse' is not supported for control type: #{control_type}"
        end
      end

      def upload_image(image_path)
        if control_type == "image"
          browser_page
            .expect_file_chooser do
              component
                .locator(".file-uploader__controls .btn.btn-default")
                .filter(visible: true)
                .click
            end
            .set_files(image_path)
        else
          raise "'upload_image' is not supported for control type: #{control_type}"
        end
      end

      def has_selected_names?(*names)
        if control_type == "tag-chooser"
          PageObjects::Components::SelectKit.new(tag_chooser_selector).has_selected_names?(*names)
        else
          raise "'has_selected_names?' is only supported for control type: tag-chooser"
        end
      end

      def disabled?
        component.get_attribute("data-disabled") == ""
      end

      def enabled?
        !disabled?
      end

      private

      def tag_chooser_selector
        "[data-name='#{component.get_attribute("data-name")}'] .form-kit__control-tag-chooser"
      end
    end

    class FormKit < PageObjects::Components::Base
      attr_reader :component

      def initialize(component)
        @component = component
      end

      def submit
        browser_root.locator("#{component} button[type='submit']").filter(visible: true).click
      end

      def reset
        browser_page.evaluate(
          "function(arguments) { var form = arguments[0]; form.dispatchEvent(new Event('reset', { bubbles: true, cancelable: true })); }",
          arg: browser_arguments(browser_root.locator(component).filter(visible: true)),
        )
      end

      def has_an_alert?(message)
        within_browser(component) do
          have_count(0).does_not_match?(
            browser_root
              .locator(".form-kit__alert-message")
              .filter(visible: true)
              .filter(hasText: browser_text_pattern(message)),
          )
        end
      end

      def collection_field(collection_name, collection_index, field_name)
        FormKitField.new(
          browser_root.locator(
            ".form-kit__field[data-name='#{collection_name}.#{collection_index}.#{field_name}']",
          ).filter(visible: true),
        )
      end

      def field(name)
        within_browser(component) do
          FormKitField.new(
            browser_root.locator(".form-kit__field[data-name='#{name}']").filter(visible: true),
          )
        end
      end

      def has_field_with_name?(name)
        have_count(0).does_not_match?(
          browser_root.locator(".form-kit__field[data-name='#{name}']").filter(visible: true),
        )
      end

      def has_no_field_with_name?(name)
        have_count(0).matches?(
          browser_root.locator(".form-kit__field[data-name='#{name}']").filter(visible: true),
        )
      end

      def has_no_enabled_field_with_name?(name)
        have_count(0).matches?(
          browser_root.locator(".form-kit__field[data-name='#{name}']:not([data-disabled])").filter(
            visible: true,
          ),
        )
      end

      def container(name)
        within_browser(component) do
          FormKitContainer.new(
            browser_root.locator(".form-kit__container[data-name='#{name}']").filter(visible: true),
          )
        end
      end

      def choose_conditional(name)
        within_browser(component) do
          browser_root
            .locator("input.form-kit__control-radio[value='#{name}']")
            .locator("xpath=ancestor::*")
            .and(browser_page.locator("label"))
            .last
            .click
        end
      end
    end
  end
end
