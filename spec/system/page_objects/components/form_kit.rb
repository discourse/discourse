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
        component["data-value"]
      end

      def control_type
        component["data-control-type"]
      end

      def toggle
        if control_type == "checkbox"
          component.find("input[type='checkbox']").click
        else
          raise "'toggle' is not supported for control type: #{control_type}"
        end
      end

      def fill_in(value)
        case control_type
        when "input"
          component.find("input").fill_in(with: value)
        when "code", "text", "composer"
          component.find("textarea").fill_in(with: value)
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

      def field(name)
        within component do
          FormKitField.new(find(".form-kit__field[data-name='#{name}']"))
        end
      end
    end
  end
end
