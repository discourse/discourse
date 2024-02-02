# frozen_string_literal: true

RSpec.describe ThemeSetting do
  fab!(:theme)

  context "for validations" do
    it "should be invalid when setting data_type to objects and `experimental_objects_type_for_theme_settings` is disabled" do
      SiteSetting.experimental_objects_type_for_theme_settings = false

      theme_setting =
        ThemeSetting.new(name: "test", data_type: ThemeSetting.types[:objects], theme:)

      expect(theme_setting.valid?).to eq(false)
      expect(theme_setting.errors[:data_type]).to contain_exactly("is not included in the list")
    end

    it "should be valid when setting data_type to objects and `experimental_objects_type_for_theme_settings` is enabled" do
      SiteSetting.experimental_objects_type_for_theme_settings = true

      theme_setting =
        ThemeSetting.new(name: "test", data_type: ThemeSetting.types[:objects], theme:)

      expect(theme_setting.valid?).to eq(true)
    end
  end
end
