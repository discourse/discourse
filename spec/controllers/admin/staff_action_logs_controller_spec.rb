require 'rails_helper'

describe Admin::StaffActionLogsController do
  it "is a subclass of AdminController" do
    expect(Admin::StaffActionLogsController < Admin::AdminController).to eq(true)
  end

  let!(:user) { log_in(:admin) }

  context '.index' do

    it 'generates logs' do

      topic = Fabricate(:topic)
      _record = StaffActionLogger.new(Discourse.system_user).log_topic_delete_recover(topic, "delete_topic")

      get :index, params: { action_id: UserHistory.actions[:delete_topic] }, format: :json

      json = JSON.parse(response.body)
      expect(response).to be_success

      expect(json["staff_action_logs"].length).to eq(1)
      expect(json["staff_action_logs"][0]["action_name"]).to eq("delete_topic")

      expect(json["user_history_actions"]).to include("id" => UserHistory.actions[:delete_topic], "name" => 'delete_topic')

    end
  end

  context '.diff' do
    it 'can generate diffs for theme changes' do
      theme = Theme.new(user_id: -1, name: 'bob')
      theme.set_field(target: :mobile, name: :scss, value: 'body {.up}')
      theme.set_field(target: :common, name: :scss, value: 'omit-dupe')

      original_json = ThemeSerializer.new(theme, root: false).to_json

      theme.set_field(target: :mobile, name: :scss, value: 'body {.down}')

      record = StaffActionLogger.new(Discourse.system_user)
        .log_theme_change(original_json, theme)

      get :diff, params: { id: record.id }, format: :json
      expect(response).to be_success

      parsed = JSON.parse(response.body)
      expect(parsed["side_by_side"]).to include("up")
      expect(parsed["side_by_side"]).to include("down")

      expect(parsed["side_by_side"]).not_to include("omit-dupe")
    end
  end
end
