# frozen_string_literal: true

RSpec.describe Admin::StaffActionLogsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }

  describe "#index" do
    shared_examples "staff action logs accessible" do
      it "returns logs" do
        topic = Fabricate(:topic)
        StaffActionLogger.new(Discourse.system_user).log_topic_delete_recover(topic, "delete_topic")

        get "/admin/logs/staff_action_logs.json",
            params: {
              action_id: UserHistory.actions[:delete_topic],
            }

        json = response.parsed_body
        expect(response.status).to eq(200)

        expect(json["staff_action_logs"].length).to eq(1)
        expect(json["staff_action_logs"][0]["action_name"]).to eq("delete_topic")

        expect(json["extras"]["user_history_actions"]).to include(
          "id" => "delete_topic",
          "action_id" => UserHistory.actions[:delete_topic],
        )
      end

      describe "when limit params is invalid" do
        include_examples "invalid limit params",
                         "/admin/logs/staff_action_logs.json",
                         described_class::INDEX_LIMIT
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "staff action logs accessible"

      it "generates logs with pages" do
        1
          .upto(4)
          .each do |idx|
            StaffActionLogger.new(Discourse.system_user).log_site_setting_change(
              "title",
              "value #{idx - 1}",
              "value #{idx}",
            )
          end

        get "/admin/logs/staff_action_logs.json", params: { limit: 3 }

        json = response.parsed_body
        expect(response.status).to eq(200)
        expect(json["staff_action_logs"].length).to eq(3)
        expect(json["staff_action_logs"][0]["new_value"]).to eq("value 4")

        get "/admin/logs/staff_action_logs.json", params: { limit: 3, page: 1 }

        json = response.parsed_body
        expect(response.status).to eq(200)
        expect(json["staff_action_logs"].length).to eq(1)
        expect(json["staff_action_logs"][0]["new_value"]).to eq("value 1")
      end

      context "when staff actions are extended" do
        let(:plugin_extended_action) { :confirmed_ham }
        before { UserHistory.stubs(:staff_actions).returns([plugin_extended_action]) }
        after { UserHistory.unstub(:staff_actions) }

        it "Uses the custom_staff id" do
          get "/admin/logs/staff_action_logs.json", params: {}

          json = response.parsed_body
          action = json["extras"]["user_history_actions"].first

          expect(action["id"]).to eq plugin_extended_action.to_s
          expect(action["action_id"]).to eq UserHistory.actions[:custom_staff]
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "staff action logs accessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/logs/staff_action_logs.json",
            params: {
              action_id: UserHistory.actions[:delete_topic],
            }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end

  describe "#diff" do
    shared_examples "theme diffs accessible" do
      it "generates diffs for theme changes" do
        theme = Fabricate(:theme)
        theme.set_field(target: :mobile, name: :scss, value: "body {.up}")
        theme.set_field(target: :common, name: :scss, value: "omit-dupe")

        original_json =
          ThemeSerializer.new(theme, root: false, include_theme_field_values: true).to_json

        theme.set_field(target: :mobile, name: :scss, value: "body {.down}")

        record = StaffActionLogger.new(Discourse.system_user).log_theme_change(original_json, theme)

        get "/admin/logs/staff_action_logs/#{record.id}/diff.json"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expect(parsed["side_by_side"]).to include("up")
        expect(parsed["side_by_side"]).to include("down")

        expect(parsed["side_by_side"]).not_to include("omit-dupe")
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "theme diffs accessible"

      it "is not erroring when current value is empty" do
        theme = Fabricate(:theme)
        StaffActionLogger.new(admin).log_theme_destroy(theme)
        get "/admin/logs/staff_action_logs/#{UserHistory.last.id}/diff.json"
        expect(response.status).to eq(200)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme diffs accessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        theme = Fabricate(:theme)
        StaffActionLogger.new(admin).log_theme_destroy(theme)

        get "/admin/logs/staff_action_logs/#{UserHistory.last.id}/diff.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end
  end
end
