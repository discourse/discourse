# frozen_string_literal: true

require "rails_helper"

RSpec.describe Report do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  fab!(:group1) do
    group = Fabricate(:group)
    group.add(user1)
    group.add(user2)
    group
  end

  fab!(:policy) do
    policy = Fabricate(:post_policy)
    PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group1.id)
    policy
  end

  before do
    enable_current_plugin
    PolicyUser.add!(user1, policy)
  end

  it "reports users who have not accepted" do
    report = Report.find("unaccepted-policies")
    topic = policy.post.topic
    expect(report.data).to eq([{ topic_id: topic.id, user_id: user2.id }])
  end
end
