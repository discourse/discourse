# frozen_string_literal: true

RSpec.describe Admin::Config::UpcomingChangesController do
  fab!(:admin)
  fab!(:user)

  describe "#index" do
    before do
      @original_upcoming_changes_metadata = SiteSetting.upcoming_change_metadata.dup

      SiteSetting.instance_variable_set(
        :@upcoming_change_metadata,
        @original_upcoming_changes_metadata.merge(
          {
            enable_upload_debug_mode: {
              impact: "other,developers",
              status: :pre_alpha,
              impact_type: "feature",
              impact_role: "admins",
            },
          },
        ),
      )
    end

    after do
      SiteSetting.instance_variable_set(
        :@upcoming_change_metadata,
        @original_upcoming_changes_metadata,
      )
    end

    context "when logged in as non-admin" do
      before { sign_in(user) }

      it "returns 404" do
        get "/admin/config/upcoming-changes.json", xhr: true
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "lists upcoming changes" do
        get "/admin/config/upcoming-changes.json", xhr: true

        expect(response.status).to eq(200)
        expect(response.parsed_body["upcoming_changes"]).to be_an(Array)
      end

      it "includes the mocked upcoming change" do
        get "/admin/config/upcoming-changes.json", xhr: true

        mock_setting =
          response.parsed_body["upcoming_changes"].find do |change|
            change["setting"] == "enable_upload_debug_mode"
          end

        expect(mock_setting).to include(
          "setting" => "enable_upload_debug_mode",
          "humanized_name" => "Enable upload debug mode",
          "value" => SiteSetting.enable_upload_debug_mode,
          "upcoming_change" => {
            "impact" => "other,developers",
            "impact_role" => "admins",
            "impact_type" => "feature",
            "status" => "pre_alpha",
          },
        )
      end

      it "includes group names when site setting groups are configured" do
        SiteSettingGroup.create!(name: "enable_upload_debug_mode", group_ids: "10|11")
        SiteSetting.refresh!

        get "/admin/config/upcoming-changes.json", xhr: true

        mock_setting =
          response.parsed_body["upcoming_changes"].find do |change|
            change["setting"] == "enable_upload_debug_mode"
          end

        expect(mock_setting["groups"]).to eq(%w[trust_level_0 trust_level_1])
      end
    end
  end

  describe "#update_groups" do
    let(:setting_name) { "enable_upload_debug_mode" }

    context "when logged in as non-admin" do
      before { sign_in(user) }

      it "returns 404" do
        put "/admin/config/upcoming-changes/groups.json",
            params: {
              group_names: %w[trust_level_0 admins],
              setting: setting_name,
            }
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "returns 200 on success" do
        put "/admin/config/upcoming-changes/groups.json",
            params: {
              group_names: %w[trust_level_0 admins],
              setting: setting_name,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
      end

      it "creates a site setting group record" do
        expect {
          put "/admin/config/upcoming-changes/groups.json",
              params: {
                group_names: %w[trust_level_0 admins],
                setting: setting_name,
              }
        }.to change { SiteSettingGroup.count }.by(1)

        site_setting_group = SiteSettingGroup.find_by(name: setting_name)
        expect(site_setting_group.group_ids.split("|").sort).to eq(%w[1 10])
      end

      it "updates an existing site setting group record" do
        SiteSettingGroup.create!(name: setting_name, group_ids: "10|13")

        expect {
          put "/admin/config/upcoming-changes/groups.json",
              params: {
                group_names: %w[admins trust_level_3],
                setting: setting_name,
              }
        }.not_to change { SiteSettingGroup.count }

        expect(SiteSettingGroup.find_by(name: setting_name).group_ids).to eq("13|1")
      end

      it "deletes an existing site setting group record" do
        SiteSettingGroup.create!(name: setting_name, group_ids: "10|13")

        expect {
          put "/admin/config/upcoming-changes/groups.json",
              params: {
                group_names: [],
                setting: setting_name,
              }
        }.to change { SiteSettingGroup.count }.by(-1)

        expect(SiteSettingGroup.find_by(name: setting_name)).to not_exist
      end

      it "logs the change in staff action logs" do
        expect {
          put "/admin/config/upcoming-changes/groups.json",
              params: {
                group_names: %w[trust_level_0 admins],
                setting: setting_name,
              }
        }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_site_setting_groups],
            subject: setting_name,
          ).count
        }.by(1)
      end

      it "returns 400 when group_names is missing" do
        put "/admin/config/upcoming-changes/groups.json", params: { setting: setting_name }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns 400 when setting is missing" do
        put "/admin/config/upcoming-changes/groups.json",
            params: {
              group_names: %w[trust_level_0 admins],
            }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns 204 when group_names is empty" do
        put "/admin/config/upcoming-changes/groups.json",
            params: {
              group_names: [],
              setting: setting_name,
            }

        expect(response.status).to eq(204)
      end

      it "only includes existing groups when some don't exist" do
        put "/admin/config/upcoming-changes/groups.json",
            params: {
              group_names: %w[trust_level_0 nonexistent_group admins],
              setting: setting_name,
            }

        expect(response.status).to eq(200)
        site_setting_group = SiteSettingGroup.find_by(name: setting_name)
        expect(site_setting_group.group_ids.split("|").sort).to eq(%w[1 10])
      end
    end
  end

  describe "#toggle_change" do
    let(:setting_name) { "experimental_form_templates" }

    context "when logged in as non-admin" do
      before { sign_in(user) }

      it "returns 404" do
        put "/admin/config/upcoming-changes/toggle.json", params: { setting_name: }
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "returns 200 on success" do
        put "/admin/config/upcoming-changes/toggle.json", params: { setting_name: }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
      end

      it "toggles the setting from false to true" do
        SiteSetting.experimental_form_templates = false

        expect {
          put "/admin/config/upcoming-changes/toggle.json", params: { setting_name: }
        }.to change { SiteSetting.experimental_form_templates }.from(false).to(true)
      end

      it "toggles the setting from true to false" do
        SiteSetting.experimental_form_templates = true

        expect {
          put "/admin/config/upcoming-changes/toggle.json", params: { setting_name: }
        }.to change { SiteSetting.experimental_form_templates }.from(true).to(false)
      end

      it "logs the change in staff action logs" do
        expect {
          put "/admin/config/upcoming-changes/toggle.json", params: { setting_name: }
        }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_site_setting],
            subject: setting_name,
          ).count
        }.by(1)
      end

      it "returns 400 when setting_name is missing" do
        put "/admin/config/upcoming-changes/toggle.json"

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns 403 when setting_name is invalid" do
        put "/admin/config/upcoming-changes/toggle.json",
            params: {
              setting_name: "nonexistent_setting",
            }

        expect(response.status).to eq(403)
      end
    end
  end
end
