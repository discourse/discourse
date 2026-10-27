# frozen_string_literal: true

RSpec.describe Admin::Config::UpcomingChangesController do
  fab!(:admin)
  fab!(:user)

  describe "#index" do
    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
          },
        },
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
            "impact_role" => "developers",
            "impact_type" => "other",
            "status" => "experimental",
            "enabled_for" => "no_one",
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

        expect(mock_setting["groups"]).to eq("trust_level_0,trust_level_1")
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

        expect(SiteSettingGroup.find_by(name: setting_name).group_ids).to eq("1|13")
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

        expect(response.status).to eq(200)
        expect(SiteSettingGroup.exists?(name: setting_name)).to be_falsey
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

      it "returns 400 when setting is missing" do
        put "/admin/config/upcoming-changes/groups.json",
            params: {
              group_names: %w[trust_level_0 admins],
            }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
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

  describe "#update_groups with a linked site setting" do
    let(:setting) { "enable_upload_debug_mode" }

    before do
      sign_in(admin)
      mock_upcoming_change_metadata(
        enable_upload_debug_mode: {
          status: :experimental,
          group_setting: :hidden_post_visible_groups,
        },
      )
      SiteSetting.enable_upload_debug_mode = false
    end

    it "returns the saved audience and the linked setting descriptor" do
      put "/admin/config/upcoming-changes/groups.json",
          params: {
            setting:,
            group_names: ["trust_level_2"],
          },
          as: :json

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "success" => "OK",
        "groups" => "admins,moderators,trust_level_2",
        "group_setting" =>
          include(
            "setting" => "hidden_post_visible_groups",
            "value" => "1|2|12",
            "mandatory_values" => "1|2",
            "disallowed_groups" => "4",
          ),
      )
      expect(SiteSetting.enable_upload_debug_mode).to eq(false)
      expect(SiteSettingGroup.where(name: setting)).to be_empty
    end

    it "rejects an empty audience while preserving the flag and linked setting" do
      previous_value = SiteSetting.hidden_post_visible_groups

      put "/admin/config/upcoming-changes/groups.json",
          params: {
            setting:,
            group_names: [],
          },
          as: :json

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to be_present
      expect(SiteSetting.hidden_post_visible_groups).to eq(previous_value)
      expect(SiteSetting.enable_upload_debug_mode).to eq(false)
    end

    it "rejects disallowed groups without updating the linked setting" do
      previous_value = SiteSetting.hidden_post_visible_groups

      put "/admin/config/upcoming-changes/groups.json",
          params: {
            setting:,
            group_names: ["anonymous_users"],
          },
          as: :json

      expect(response.status).to eq(422)
      expect(SiteSetting.hidden_post_visible_groups).to eq(previous_value)
    end
  end

  describe "#toggle_change" do
    before do
      mock_upcoming_change_metadata(
        enable_form_templates: {
          impact: "feature,all_members",
          status: :experimental,
        },
      )
    end

    let(:setting_name) { "enable_form_templates" }

    context "when logged in as non-admin" do
      before { sign_in(user) }

      it "returns 404" do
        put "/admin/config/upcoming-changes/toggle.json", params: { setting_name:, enabled: true }
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "returns 200 on success" do
        put "/admin/config/upcoming-changes/toggle.json", params: { setting_name:, enabled: true }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
      end

      it "toggles the setting from false to true" do
        SiteSetting.enable_form_templates = false

        expect {
          put "/admin/config/upcoming-changes/toggle.json", params: { setting_name:, enabled: true }
        }.to change { SiteSetting.enable_form_templates }.from(false).to(true)
      end

      it "toggles the setting from true to false" do
        SiteSetting.enable_form_templates = true

        expect {
          put "/admin/config/upcoming-changes/toggle.json",
              params: {
                setting_name:,
                enabled: false,
              }
        }.to change { SiteSetting.enable_form_templates }.from(true).to(false)
      end

      it "accepts an empty JSON audience while disabling the change" do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            allow_enabled_for: [:specific_groups],
          },
        )
        SiteSetting.enable_form_templates = true
        Fabricate(:site_setting_group, name: setting_name, group_ids: "12")

        put "/admin/config/upcoming-changes/toggle.json",
            params: {
              setting_name:,
              enabled: false,
              group_names: [],
            },
            as: :json

        expect(response.status).to eq(200)
        expect(SiteSetting.enable_form_templates).to eq(false)
        expect(SiteSettingGroup.where(name: setting_name)).to be_empty
      end

      it "accepts a JSON audience and enables a staff-inclusive change together" do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            allow_enabled_for: %i[staff specific_groups],
          },
        )
        SiteSetting.enable_form_templates = false

        put "/admin/config/upcoming-changes/toggle.json",
            params: {
              setting_name:,
              enabled: true,
              group_names: %w[staff trust_level_2],
            },
            as: :json

        expect(response.status).to eq(200)
        expect(SiteSetting.enable_form_templates).to eq(true)
        expect(SiteSettingGroup.find_by(name: setting_name).group_ids).to eq("3|12")
      end

      it "toggles a linked change independently while preserving its configured audience" do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            group_setting: :about_page_extra_groups,
          },
        )
        SiteSetting.enable_form_templates = false
        SiteSetting.about_page_extra_groups = ""

        put "/admin/config/upcoming-changes/toggle.json",
            params: {
              setting_name:,
              enabled: true,
            },
            as: :json

        expect(response.status).to eq(200)
        expect(SiteSetting.enable_form_templates).to eq(true)
        expect(SiteSetting.about_page_extra_groups).to eq("")
      end

      it "logs the change in staff action logs" do
        expect {
          put "/admin/config/upcoming-changes/toggle.json", params: { setting_name:, enabled: true }
        }.to change {
          UserHistory.where(
            action: UserHistory.actions[:upcoming_change_toggled],
            subject: setting_name,
            context: I18n.t("staff_action_logs.upcoming_changes.log_manually_toggled"),
          ).count
        }.by(1)
      end

      it "returns 400 when setting_name is missing" do
        put "/admin/config/upcoming-changes/toggle.json"

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns 404 when setting_name is invalid" do
        put "/admin/config/upcoming-changes/toggle.json",
            params: {
              setting_name: "nonexistent_setting",
              enabled: true,
            }

        expect(response.status).to eq(404)
      end

      it "rejects SiteSetting methods that are not upcoming changes" do
        messages =
          MessageBus.track_publish(SiteSettingExtension::SITE_SETTINGS_CHANNEL) do
            put "/admin/config/upcoming-changes/toggle.json",
                params: {
                  setting_name: "notify_changed!",
                  enabled: true,
                }
          end

        aggregate_failures do
          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
          expect(messages).to be_empty
        end
      end
    end
  end
end
