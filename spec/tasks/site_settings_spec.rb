# frozen_string_literal: true

RSpec.describe "tasks/site_settings" do
  describe "site_settings:normalize_object_uploads" do
    fab!(:theme)
    fab!(:upload)

    it "normalizes upload URLs in object settings" do
      SiteSetting.create!(
        name: "ui_cards_setting",
        data_type: SiteSettings::TypeSupervisor.types[:objects],
        value: JSON.generate([{ "title" => "Site card", "image" => upload.url }]),
      )

      theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
        cards:
          type: objects
          default: []
          schema:
            name: card
            identifier: title
            properties:
              title:
                type: string
                required: true
              image:
                type: upload
      YAML
      theme.save!

      ThemeSetting.create!(
        theme:,
        name: "cards",
        data_type: ThemeSetting.types[:objects],
        json_value: [{ "title" => "Theme card", "image" => upload.url }],
      )

      output = capture_stdout { invoke_rake_task("site_settings:normalize_object_uploads") }

      expect(output).to include("Changed:      2")
      expect(JSON.parse(SiteSetting.find_by(name: "ui_cards_setting").value)).to eq(
        [{ "title" => "Site card", "image" => upload.id }],
      )
      expect(ThemeSetting.find_by(name: "cards").json_value).to eq(
        [{ "title" => "Theme card", "image" => upload.id }],
      )
    end

    it "does not persist changes in dry run mode" do
      SiteSetting.create!(
        name: "ui_cards_setting",
        data_type: SiteSettings::TypeSupervisor.types[:objects],
        value: JSON.generate([{ "title" => "Site card", "image" => upload.url }]),
      )

      previous_dry_run = ENV["DRY_RUN"]
      ENV["DRY_RUN"] = "1"
      begin
        output = capture_stdout { invoke_rake_task("site_settings:normalize_object_uploads") }

        expect(output).to include("Would normalize site setting ui_cards_setting")
        expect(output).to include("Changed:      1")
      ensure
        ENV["DRY_RUN"] = previous_dry_run
      end

      expect(JSON.parse(SiteSetting.find_by(name: "ui_cards_setting").value)).to eq(
        [{ "title" => "Site card", "image" => upload.url }],
      )
    end
  end
end
