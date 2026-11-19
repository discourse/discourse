# frozen_string_literal: true

RSpec.describe "Group assignment notifications" do
  fab!(:admin)
  fab!(:member) { Fabricate(:user, last_seen_at: 1.minute.ago) }
  fab!(:authorized_member, :user)
  fab!(:category_group, :group)
  fab!(:assigned_group, :public_group)
  fab!(:private_category) { Fabricate(:private_category, group: category_group) }
  fab!(:private_topic) do
    Fabricate(:topic_with_op, category: private_category, title: "Restricted assignment title")
  end

  before do
    Jobs.run_immediately!
    SiteSetting.assign_enabled = true
    assigned_group.update!(assignable_level: Group::ALIAS_LEVELS[:everyone])
    assigned_group.add(authorized_member)
    category_group.add(authorized_member)
    Assigner.new(private_topic, admin).assign(assigned_group)
  end

  it "does not notify a member who joins the group about a target they can't see" do
    sign_in(member)

    alerts =
      MessageBus.track_publish("/notification-alert/#{member.id}") do
        put "/groups/#{assigned_group.id}/join.json"
      end

    expect(response.status).to eq(204)
    expect(alerts).to be_empty
    expect(member.notifications.assigned).to be_empty
    expect(authorized_member.notifications.assigned.map { |n| n.data_hash["topic_title"] }).to eq(
      [private_topic.title],
    )
  end

  it "notifies a member who joins the group about a target they can see" do
    category_group.add(member)
    sign_in(member)

    alerts =
      MessageBus.track_publish("/notification-alert/#{member.id}") do
        put "/groups/#{assigned_group.id}/join.json"
      end

    expect(response.status).to eq(204)
    expect(alerts.map { |alert| alert.data[:topic_title] }).to eq([private_topic.title])
    expect(member.notifications.assigned.count).to eq(1)
  end
end
