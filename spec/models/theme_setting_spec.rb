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

    it "should be invalid when json_value size is greater than the maximum allowed size" do
      SiteSetting.experimental_objects_type_for_theme_settings = true

      json_value = { "key" => "value" }
      bytesize = json_value.to_json.bytesize

      expect(bytesize).to eq(15)

      stub_const(ThemeSetting, "MAXIMUM_JSON_VALUE_SIZE_BYTES", bytesize - 1) do
        theme_setting =
          ThemeSetting.new(
            name: "test",
            data_type: ThemeSetting.types[:objects],
            theme:,
            json_value:,
          )

        expect(theme_setting.valid?).to eq(false)

        expect(theme_setting.errors[:json_value]).to contain_exactly(
          I18n.t(
            "theme_settings.errors.json_value.too_large",
            max_size_megabytes: (bytesize - 1) / 1024 / 1024,
          ),
        )
      end
    end
  end
end
