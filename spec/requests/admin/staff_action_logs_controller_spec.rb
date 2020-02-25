# frozen_string_literal: true

require 'rails_helper'

describe Admin::StaffActionLogsController do
  it "is a subclass of AdminController" do
    expect(Admin::StaffActionLogsController < Admin::AdminController).to eq(true)
  end

  fab!(:admin) { Fabricate(:admin) }

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

      expect(json["extras"]["user_history_actions"]).to include(
        "id" => 'delete_topic', "action_id" => UserHistory.actions[:delete_topic]
      )
    end

    it 'generates logs with pages' do
      1.upto(4).each do |idx|
        StaffActionLogger.new(Discourse.system_user).log_site_setting_change("title", "value #{idx - 1}", "value #{idx}")
      end

      get "/admin/logs/staff_action_logs.json", params: { limit: 3 }

      json = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(json["staff_action_logs"].length).to eq(3)
      expect(json["staff_action_logs"][0]["new_value"]).to eq("value 4")

      get "/admin/logs/staff_action_logs.json", params: { limit: 3, page: 1 }

      json = JSON.parse(response.body)
      expect(response.status).to eq(200)
      expect(json["staff_action_logs"].length).to eq(1)
      expect(json["staff_action_logs"][0]["new_value"]).to eq("value 1")
    end

    context 'When staff actions are extended' do
      let(:plugin_extended_action) { :confirmed_ham }
      before { UserHistory.stubs(:staff_actions).returns([plugin_extended_action]) }
      after { UserHistory.unstub(:staff_actions) }

      it 'Uses the custom_staff id' do
        get "/admin/logs/staff_action_logs.json", params: {}

        json = JSON.parse(response.body)
        action = json['extras']['user_history_actions'].first

        expect(action['id']).to eq plugin_extended_action.to_s
        expect(action['action_id']).to eq UserHistory.actions[:custom_staff]
      end
    end
  end

  describe '#diff' do
    it 'can generate diffs for theme changes' do
      theme = Fabricate(:theme)
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

    it 'is not erroring when current value is empty' do
      theme = Fabricate(:theme)
      StaffActionLogger.new(admin).log_theme_destroy(theme)
      get "/admin/logs/staff_action_logs/#{UserHistory.last.id}/diff.json"
      expect(response.status).to eq(200)
    end
  end
end
