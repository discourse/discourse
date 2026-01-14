# frozen_string_literal: true

RSpec.describe ThemeSetting do
  fab!(:theme)

  describe "creating upload references for objects settings with upload fields" do
    fab!(:upload)
    fab!(:upload2, :upload)

    let(:objects_setting_yaml) { <<~YAML }
        objects_with_upload:
          type: objects
          default: []
          schema:
            name: test_object
            properties:
              name:
                type: string
              image:
                type: upload
      YAML

    it "creates upload references for type objects settings with upload fields" do
      theme.set_field(target: :settings, name: "yaml", value: objects_setting_yaml)
      theme.save!

      theme.settings[:objects_with_upload].value = [
        { "name" => "object1", "image" => upload.id },
        { "name" => "object2", "image" => upload2.id },
      ]

      theme_setting = theme.theme_settings.find_by(name: "objects_with_upload")
      upload_references = UploadReference.where(target: theme_setting)
      expect(upload_references.pluck(:upload_id)).to contain_exactly(upload.id, upload2.id)
    end

    it "destroys upload references for type objects setting when the setting is destroyed" do
      theme.set_field(target: :settings, name: "yaml", value: objects_setting_yaml)
      theme.save!

      theme.settings[:objects_with_upload].value = [
        { "name" => "object1", "image" => upload.id },
        { "name" => "object2", "image" => upload2.id },
      ]

      theme_setting = theme.theme_settings.find_by(name: "objects_with_upload")
      expect { theme_setting.destroy! }.to change { UploadReference.count }.by(-2)
    end
  end

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
