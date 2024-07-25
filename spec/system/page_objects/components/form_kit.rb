# frozen_string_literal: true

module PageObjects
  module Components
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
        when "icon"
          picker = PageObjects::Components::SelectKit.new(component)
          picker.value
        when "checkbox"
          component.find("input[type='checkbox']").checked?
        when "menu"
          component.find(".fk-d-menu__trigger")["data-value"]
        when "select"
          component.find("select").value
        when "composer"
          component.find("textarea").value
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

      def control_type
        component["data-control-type"]
      end

      def toggle
        case control_type
        when "checkbox"
          component.find("input[type='checkbox']").click
        when "password"
          component.find(".form-kit__control-password-toggle").click
        else
          raise "'toggle' is not supported for control type: #{control_type}"
        end
      end

      def fill_in(value)
        case control_type
        when "input-text", "password"
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
        when "select"
          component.find(".form-kit__control-option[value='#{value}']").click
        when "menu"
          trigger = component.find(".fk-d-menu__trigger.form-kit__control-menu")
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
          raise "'accept' is not supported for control type: #{control_type}"
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
        page.execute_script(
          "var form = arguments[0]; form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));",
          find(component),
        )
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
    end
  end
end
