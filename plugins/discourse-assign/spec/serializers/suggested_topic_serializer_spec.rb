# frozen_string_literal: true

require "rails_helper"

RSpec.describe SuggestedTopicSerializer do
  fab!(:user)
  fab!(:group) { Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone]) }
  fab!(:group_user) { Fabricate(:group_user, group: group, user: user) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:topic2) { Fabricate(:topic) }
  fab!(:post2) { Fabricate(:post, topic: topic2) }
  fab!(:guardian) { Guardian.new(user) }
  fab!(:serializer) { described_class.new(topic, scope: guardian) }
  fab!(:serializer2) { described_class.new(topic2, scope: guardian) }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = group.id.to_s
  end

  it "adds information about assignee for users and groups" do
    Assigner.new(topic, user).assign(user)
    expect(serializer.as_json[:suggested_topic][:assigned_to_user][:username]).to eq(user.username)

    Assigner.new(topic2, user).assign(group)
    expect(serializer2.as_json[:suggested_topic][:assigned_to_group][:name]).to eq(group.name)
  end
end
