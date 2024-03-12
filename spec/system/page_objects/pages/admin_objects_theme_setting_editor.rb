# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminObjectsThemeSettingEditor < PageObjects::Pages::Base
      def has_setting_field?(field_name, value)
        expect(input_field(field_name).value).to eq(value)
      end

      def fill_in_field(field_name, value)
        input_field(field_name).fill_in(with: value)
        self
      end

      def save
        click_button(I18n.t("js.save"))
        self
      end

      private

      def input_field(field_name)
        page.find(".schema-field[data-name=\"#{field_name}\"] input")
      end
    end
  end
end
