# frozen_string_literal: true

RSpec.describe Admin::StaffActionLogsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

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

      describe "filter logs by date" do
        before do
          freeze_time
          topic = Fabricate(:topic)
          StaffActionLogger.new(Discourse.system_user).log_topic_delete_recover(
            topic,
            "delete_topic",
          )
          freeze_time 3.days.from_now
          StaffActionLogger.new(Discourse.system_user).log_silence_user(user, details: "test")
          freeze_time 2.days.from_now
          StaffActionLogger.new(Discourse.system_user).log_user_suspend(user, "reason")
        end

        it "filter logs by start_date" do
          get "/admin/logs/staff_action_logs.json", params: { start_date: 3.days.ago.iso8601 }

          json = response.parsed_body
          expect(response.status).to eq(200)

          expect(json["staff_action_logs"].length).to eq(2)
          expect(json["staff_action_logs"][0]["action_name"]).to eq("suspend_user")
          expect(json["staff_action_logs"][1]["action_name"]).to eq("silence_user")
        end

        it "filter logs by end_date" do
          get "/admin/logs/staff_action_logs.json", params: { end_date: 1.day.ago.iso8601 }

          json = response.parsed_body
          expect(response.status).to eq(200)

          expect(json["staff_action_logs"].length).to eq(2)
          expect(json["staff_action_logs"][0]["action_name"]).to eq("silence_user")
          expect(json["staff_action_logs"][1]["action_name"]).to eq("delete_topic")
        end

        it "filter logs by start_date and end_date" do
          get "/admin/logs/staff_action_logs.json",
              params: {
                start_date: 3.days.ago.iso8601,
                end_date: 1.day.ago.iso8601,
              }

          json = response.parsed_body
          expect(response.status).to eq(200)

          expect(json["staff_action_logs"].length).to eq(1)
          expect(json["staff_action_logs"][0]["action_name"]).to eq("silence_user")
        end
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
        4.times do |idx|
          StaffActionLogger.new(Discourse.system_user).log_site_setting_change(
            "title",
            "value #{idx}",
            "value #{idx + 1}",
          )
        end

        get "/admin/logs/staff_action_logs.json", params: { limit: 3 }
        expect(response.parsed_body["staff_action_logs"].length).to eq(3)
        expect(response.parsed_body["staff_action_logs"][0]["new_value"]).to eq("value 4")

        get "/admin/logs/staff_action_logs.json", params: { limit: 3, page: 1 }
        expect(response.parsed_body["staff_action_logs"].length).to eq(1)
        expect(response.parsed_body["staff_action_logs"][0]["new_value"]).to eq("value 1")
      end

      it "sees admin-only actions" do
        StaffActionLogger.new(admin).log_site_setting_change("title", "old", "new")

        get "/admin/logs/staff_action_logs.json"

        expect(response.parsed_body["staff_action_logs"].map { |l| l["action_name"] }).to include(
          "change_site_setting",
        )
      end

      it "sees full content for private topics" do
        pm = Fabricate(:private_message_topic)
        StaffActionLogger.new(admin).log_topic_delete_recover(pm, "delete_topic")

        get "/admin/logs/staff_action_logs.json"

        expect(response.parsed_body["staff_action_logs"].first["details"]).to include(pm.title)
      end

      context "when staff actions are extended" do
        let(:plugin_extended_action) { :confirmed_ham }
        before { UserHistory.stubs(:staff_actions).returns([plugin_extended_action]) }
        after { UserHistory.unstub(:staff_actions) }

        it "uses custom_staff id for unknown actions" do
          get "/admin/logs/staff_action_logs.json"

          action = response.parsed_body["extras"]["user_history_actions"].first
          expect(action["id"]).to eq(plugin_extended_action.to_s)
          expect(action["action_id"]).to eq(UserHistory.actions[:custom_staff])
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "staff action logs accessible"

      it "does not see admin-only actions" do
        StaffActionLogger.new(admin).log_site_setting_change("title", "old", "new")
        StaffActionLogger.new(admin).log_web_hook(
          Fabricate(:web_hook),
          UserHistory.actions[:web_hook_create],
        )
        StaffActionLogger.new(admin).log_api_key(
          Fabricate(:api_key),
          UserHistory.actions[:api_key_create],
        )

        get "/admin/logs/staff_action_logs.json"

        action_names = response.parsed_body["staff_action_logs"].map { |l| l["action_name"] }
        expect(action_names).not_to include(
          "change_site_setting",
          "web_hook_create",
          "api_key_create",
        )
      end

      it "sees full content for public topics" do
        topic = Fabricate(:topic)
        StaffActionLogger.new(admin).log_topic_delete_recover(topic, "delete_topic")

        get "/admin/logs/staff_action_logs.json"

        expect(response.parsed_body["staff_action_logs"].first["details"]).to include(topic.title)
      end

      it "redacts content for private topics" do
        pm = Fabricate(:private_message_topic)
        StaffActionLogger.new(admin).log_topic_delete_recover(pm, "delete_topic")

        get "/admin/logs/staff_action_logs.json"

        log = response.parsed_body["staff_action_logs"].first
        expect(log["details"]).to eq(I18n.t("staff_action_logs.redacted"))
        expect(log["context"]).to be_nil
      end

      it "redacts content for restricted categories" do
        SiteSetting.moderators_manage_categories = true
        category = Fabricate(:private_category, group: Fabricate(:group))
        StaffActionLogger.new(admin).log_category_creation(category)

        get "/admin/logs/staff_action_logs.json"

        expect(response.parsed_body["staff_action_logs"].first["details"]).to eq(
          I18n.t("staff_action_logs.redacted"),
        )
      end

      it "redacts content when referenced topic is deleted" do
        topic = Fabricate(:topic)
        StaffActionLogger.new(admin).log_topic_delete_recover(topic, "delete_topic")
        topic.destroy!

        get "/admin/logs/staff_action_logs.json"

        log = response.parsed_body["staff_action_logs"].first
        expect(log["details"]).to eq(I18n.t("staff_action_logs.redacted"))
        expect(log["context"]).to be_nil
      end

      it "redacts content when referenced post is deleted" do
        post = Fabricate(:post)
        StaffActionLogger.new(admin).log_post_edit(post, old_raw: "old content")
        post.destroy!

        get "/admin/logs/staff_action_logs.json"

        expect(response.parsed_body["staff_action_logs"].first["details"]).to eq(
          I18n.t("staff_action_logs.redacted"),
        )
      end

      it "redacts content when referenced category is deleted" do
        SiteSetting.moderators_manage_categories = true
        category = Fabricate(:category)
        StaffActionLogger.new(admin).log_category_creation(category)
        category.destroy!

        get "/admin/logs/staff_action_logs.json"

        expect(response.parsed_body["staff_action_logs"].first["details"]).to eq(
          I18n.t("staff_action_logs.redacted"),
        )
      end

      it "hides category actions when moderators_manage_categories is disabled" do
        SiteSetting.moderators_manage_categories = false
        category = Fabricate(:category)
        StaffActionLogger.new(admin).log_category_creation(category)

        get "/admin/logs/staff_action_logs.json"

        action_names = response.parsed_body["staff_action_logs"].map { |l| l["action_name"] }
        expect(action_names).not_to include("create_category")
      end

      it "shows category actions when moderators_manage_categories is enabled" do
        SiteSetting.moderators_manage_categories = true
        category = Fabricate(:category)
        StaffActionLogger.new(admin).log_category_creation(category)

        get "/admin/logs/staff_action_logs.json"

        action_names = response.parsed_body["staff_action_logs"].map { |l| l["action_name"] }
        expect(action_names).to include("create_category")
      end
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

    shared_examples "tag_group diffs accessible" do
      it "generates diffs for tag_group changes" do
        tag1 = Fabricate(:tag)
        tag2 = Fabricate(:tag)
        tag3 = Fabricate(:tag)
        tag_group1 = Fabricate(:tag_group, tags: [tag1, tag2])

        old_json = TagGroupSerializer.new(tag_group1, root: false).to_json

        tag_group2 = Fabricate(:tag_group, tags: [tag2, tag3])

        new_json = TagGroupSerializer.new(tag_group2, root: false).to_json

        record =
          StaffActionLogger.new(Discourse.system_user).log_tag_group_change(
            tag_group2.name,
            old_json,
            new_json,
          )

        get "/admin/logs/staff_action_logs/#{record.id}/diff.json"
        expect(response.status).to eq(200)

        parsed = response.parsed_body

        name_diff = <<-HTML
          <h3>name</h3><p></p><table class="markdown"><tr><td class="diff-del"><del>#{tag_group1.name}</del></td><td class="diff-ins"><ins>#{tag_group2.name}</ins></td></tr></table>
        HTML
        expect(parsed["side_by_side"]).to include(name_diff.strip)
        expect(parsed["side_by_side"]).to include("<del>#{tag1.name}</del>")
        expect(parsed["side_by_side"]).to include("<ins>#{tag3.name}</ins>")
      end

      it "generates diffs for old tag_group format with tag_names" do
        tag1 = Fabricate(:tag)
        tag2 = Fabricate(:tag)
        tag3 = Fabricate(:tag)

        old_json = {
          name: "old_group",
          tag_names: [tag1.name, tag2.name],
          parent_tag_name: [],
          one_per_topic: false,
          permissions: {
            "0" => 1,
          },
        }.to_json

        new_json = {
          name: "new_group",
          tag_names: [tag2.name, tag3.name],
          parent_tag_name: [],
          one_per_topic: false,
          permissions: {
            "0" => 1,
          },
        }.to_json

        record =
          StaffActionLogger.new(Discourse.system_user).log_tag_group_change(
            "new_group",
            old_json,
            new_json,
          )

        get "/admin/logs/staff_action_logs/#{record.id}/diff.json"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expect(parsed["side_by_side"]).to include("<h3>tag_names</h3>")
        expect(parsed["side_by_side"]).to include("<del>#{tag1.name}</del>")
        expect(parsed["side_by_side"]).to include("<ins>#{tag3.name}</ins>")
      end
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      include_examples "theme diffs accessible"
      include_examples "tag_group diffs accessible"

      it "is not erroring when current value is empty" do
        theme = Fabricate(:theme)
        StaffActionLogger.new(admin).log_theme_destroy(theme)
        get "/admin/logs/staff_action_logs/#{UserHistory.last.id}/diff.json"
        expect(response.status).to eq(200)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "tag_group diffs accessible"

      it "denies access to theme diffs (admin-only action)" do
        theme = Fabricate(:theme)
        record = StaffActionLogger.new(Discourse.system_user).log_theme_change("{}", theme)

        get "/admin/logs/staff_action_logs/#{record.id}/diff.json"
        expect(response.status).to eq(404)
      end
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
