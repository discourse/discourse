# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::BadgeRevoked::V1 do
  fab!(:admin)
  fab!(:user)
  fab!(:badge)

  let!(:user_badge) { BadgeGranter.grant(badge, user) }

  def trigger_from_event(&block)
    event = DiscourseEvent.track(:user_badge_revoked, &block)
    described_class.new(*event[:params])
  end

  it "outputs the user who lost the badge and who revoked it", :aggregate_failures do
    trigger = trigger_from_event { BadgeGranter.revoke(user_badge, revoked_by: admin) }
    output = trigger.output

    expect(trigger).to be_valid
    expect(output).to include(
      user: include(id: user.id),
      badge: include(id: badge.id, grant_count: 0),
      actor: include(id: admin.id),
    )
    expect(output).to match_node_output_schema(described_class)
  end

  it "outputs a null actor when the code that revoked it didn't say" do
    trigger = trigger_from_event { BadgeGranter.revoke(user_badge) }

    expect(trigger.output[:actor]).to be_nil
  end

  it "ignores grants removed by deleting the user or the badge", :aggregate_failures do
    expect(trigger_from_event { UserDestroyer.new(admin).destroy(user) }).not_to be_valid

    other_badge = Fabricate(:badge)
    BadgeGranter.grant(other_badge, admin)
    expect(trigger_from_event { other_badge.destroy! }).not_to be_valid
  end

  it "filters by badge", :aggregate_failures do
    trigger = trigger_from_event { BadgeGranter.revoke(user_badge, revoked_by: admin) }

    expect(trigger.matches?(trigger_context(badge_id: badge.id.to_s))).to be(true)
    expect(trigger.matches?(trigger_context(badge_id: ""))).to be(true)
    expect(trigger.matches?(trigger_context(badge_id: (badge.id + 1).to_s))).to be(false)
  end
end
