# frozen_string_literal: true

RSpec.describe ThemeSetting do
  fab!(:theme)

  context "for validations" do
    it "should be invalid when json_value size is greater than the maximum allowed size" do
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
            max_size: (bytesize - 1) / 1024 / 1024,
          ),
        )
      end
    end
  end
end
