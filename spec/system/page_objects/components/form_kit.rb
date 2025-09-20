# frozen_string_literal: true

module PageObjects
  module Components
    class FormKitContainer < PageObjects::Components::Base
      attr_reader :component

      def initialize(input)
        if input.is_a?(Capybara::Node::Element)
          @component = input
        else
          @component = find(input)
        end
      end

      def has_content?(content)
        component.has_content?(content)
      end
    end

    class FormKitField < PageObjects::Components::Base
      attr_reader :component

      def initialize(input)
        if input.is_a?(Capybara::Node::Element)
          @component = input
        else
          @component = find(input)
        end
      end

      def value
        case control_type
        when /input-/, "password"
          component.find("input").value
        when "icon", "multi-select"
          picker = PageObjects::Components::SelectKit.new(component)
          picker.value
        when "checkbox"
          component.find("input[type='checkbox']").checked?
        when "menu"
          component.find(".fk-d-menu__trigger")["data-value"]
        when "select"
          PageObjects::Components::DSelect.new(component.find("select")).value
        when "composer", "textarea"
          component.find("textarea").value
        when "image"
          url = component.find(".uploaded-image-preview a.lightbox", wait: 10)[:href]
          sha1 = url.match(/(\h{40})/).captures.first
          Upload.find_by(sha1:)
        when "toggle"
          component.find("button[role=\"switch\"]", visible: :all)["aria-checked"] == "true"
        end
      end

      def unchecked?
        if control_type != "checkbox"
          raise "'unchecked?' is only supported for control type: #{control_type}"
        end

        expect(self.value).to eq(false)
      end

      def checked?
        if control_type != "checkbox"
          raise "'checked?' is only supported for control type: #{control_type}"
        end

        expect(self.value).to eq(true)
      end

      def has_value?(expected_value)
        expect(self.value).to eq(expected_value)
      end

      def has_errors?(*messages)
        within component do
          messages.all? { |m| find(".form-kit__errors", text: m) }
        end
      end

      def has_no_errors?
        !has_css?(".form-kit__errors")
      end

      def control_type
        type = component["data-control-type"]

        return type if type != "custom"

        if component.has_css?(".multi-select")
          "multi-select"
        else
          raise "Unknown custom control"
        end
      end

      def toggle
        case control_type
        when "checkbox"
          component.find("input[type='checkbox']").click
        when "password"
          component.find(".form-kit__control-password-toggle").click
        when "toggle"
          component.find("button[role=\"switch\"]", visible: :all).ancestor("label").click
        else
          raise "'toggle' is not supported for control type: #{control_type}"
        end
      end

      def fill_in(value)
        case control_type
        when "input-text", "password", "input-date", "input-number"
          component.find("input").fill_in(with: value)
        when "textarea", "composer"
          component.find("textarea").fill_in(with: value, visible: :all)
        when "code"
          component.find(".ace_text-input", visible: :all).fill_in(with: value)
        else
          raise "Unsupported control type: #{control_type}"
        end
      end

      def select(value)
        case control_type
        when "icon"
          selector = component.find(".form-kit__control-icon")["id"]
          picker = PageObjects::Components::SelectKit.new("#" + selector)
          picker.expand
          picker.search(value)
          picker.select_row_by_value(value)
        when "multi-select"
          selector = component.find(".form-kit__control-custom > .multi-select")["id"]
          picker = PageObjects::Components::SelectKit.new("#" + selector)
          picker.expand
          picker.search(value)
          picker.select_row_by_name(value)
        when "select"
          PageObjects::Components::DSelect.new(component.find(".form-kit__control-select")).select(
            value,
          )
        when "menu"
          trigger = component.find(".fk-d-menu__trigger.form-kit__control-menu-trigger")
          trigger.click
          menu = find("[aria-labelledby='#{trigger["id"]}']")
          item = menu.find(".form-kit__control-menu-item[data-value='#{value}'] .btn")
          item.click
        when "radio-group"
          radio = component.find("input[type='radio'][value='#{value}']")
          radio.click
        when "question"
          if value == true
            accept
          else
            refuse
          end
        else
          raise "Unsupported control type: #{control_type}"
        end
      end

      def accept
        if control_type == "question"
          component.find(".form-kit__control-radio[value='true']").click
        else
          raise "'accept' is not supported for control type: #{control_type}"
        end
      end

      def refuse
        if control_type == "question"
          component.find(".form-kit__control-radio[value='false']").click
        else
          raise "'refuse' is not supported for control type: #{control_type}"
        end
      end

      def upload_image(image_path)
        if control_type == "image"
          attach_file(image_path) do
            component.find(".image-upload-controls .btn.btn-default").click
          end
        else
          raise "'upload_image' is not supported for control type: #{control_type}"
        end
      end

      def disabled?
        component["data-disabled"] == ""
      end

      def enabled?
        !disabled?
      end
    end

    class FormKit < PageObjects::Components::Base
      attr_reader :component

      def initialize(component)
        @component = component
      end

      def submit
        find("#{component} button[type='submit']").click
      end

      def reset
        page.execute_script(
          "var form = arguments[0]; form.dispatchEvent(new Event('reset', { bubbles: true, cancelable: true }));",
          find(component),
        )
      end

      def has_an_alert?(message)
        within component do
          find(".form-kit__alert-message", text: message)
        end
      end

      def field(name)
        within component do
          FormKitField.new(find(".form-kit__field[data-name='#{name}']"))
        end
      end

      def has_field_with_name?(name)
        has_css?(".form-kit__field[data-name='#{name}']")
      end

      def has_no_field_with_name?(name)
        has_no_css?(".form-kit__field[data-name='#{name}']")
      end

      def container(name)
        within component do
          FormKitContainer.new(find(".form-kit__container[data-name='#{name}']"))
        end
      end

      def choose_conditional(name)
        find(".form-kit__conditional-display .form-kit__control-radio[value='#{name}']").click
      end
    end
  end
end
