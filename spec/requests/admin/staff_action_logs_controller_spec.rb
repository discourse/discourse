require 'rails_helper'

describe Admin::StaffActionLogsController do
  it "is a subclass of AdminController" do
    expect(Admin::StaffActionLogsController < Admin::AdminController).to eq(true)
  end

  let(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
  end

  describe '#index' do
    it 'generates logs' do
      topic = Fabricate(:topic)
      StaffActionLogger.new(Discourse.system_user).log_topic_delete_recover(topic, "delete_topic")

      get "/admin/logs/staff_action_logs.json", params: { action_id: UserHistory.actions[:delete_topic] }

      json = JSON.parse(response.body)
      expect(response.status).to eq(200)

      expect(json["staff_action_logs"].length).to eq(1)
      expect(json["staff_action_logs"][0]["action_name"]).to eq("delete_topic")

      expect(json["user_history_actions"]).to include("id" => UserHistory.actions[:delete_topic], "name" => 'delete_topic')
    end
  end

  describe '#diff' do
    it 'can generate diffs for theme changes' do
      theme = Theme.new(user_id: -1, name: 'bob')
      theme.set_field(target: :mobile, name: :scss, value: 'body {.up}')
      theme.set_field(target: :common, name: :scss, value: 'omit-dupe')

      original_json = ThemeSerializer.new(theme, root: false).to_json

      theme.set_field(target: :mobile, name: :scss, value: 'body {.down}')

      record = StaffActionLogger.new(Discourse.system_user)
        .log_theme_change(original_json, theme)

      get "/admin/logs/staff_action_logs/#{record.id}/diff.json"
      expect(response.status).to eq(200)

      parsed = JSON.parse(response.body)
      expect(parsed["side_by_side"]).to include("up")
      expect(parsed["side_by_side"]).to include("down")

      expect(parsed["side_by_side"]).not_to include("omit-dupe")
    end
  end
end
