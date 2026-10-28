# frozen_string_literal: true

RSpec.shared_context "with a badge to manage" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:badge)
  fab!(:post) { Fabricate(:post, user:) }

  def run_node(
    username: user.username,
    badge_id: badge.id,
    actor_username: moderator.username,
    **rest
  )
    execute_node(
      configuration: {
        "username" => username,
        "badge_id" => badge_id,
        "actor_username" => actor_username,
        **rest.stringify_keys,
      },
    )
  end

  def badge_error(key, **args)
    node_error_message(key, scope: "badge_action", item_index: 0, **args)
  end

  def staff_logs(action)
    UserHistory.where(action: UserHistory.actions[action], target_user_id: user.id)
  end
end

RSpec.shared_examples "a badge action" do |not_allowed:|
  it "refuses non-staff actors, even when nothing would change" do
    other_user = Fabricate(:user)

    expect { run_node(actor_username: other_user.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      badge_error(not_allowed, username: other_user.username, target: user.username),
    )
  end

  it "refuses staff when badges are disabled" do
    SiteSetting.enable_badges = false

    expect { run_node }.to raise_error(
      DiscourseWorkflows::NodeError,
      badge_error(not_allowed, username: moderator.username, target: user.username),
    )
  end

  it "fails on a missing badge" do
    expect { run_node(badge_id: -42) }.to raise_error(
      DiscourseWorkflows::NodeError,
      badge_error("badge_not_found", badge_id: -42),
    )
  end

  it "fails on a post id that isn't a number" do
    expect { run_node(post_id: "abc") }.to raise_error(
      DiscourseWorkflows::NodeError,
      badge_error("post_not_found", post_id: "abc"),
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::GrantBadge::V1 do
  include_context "with a badge to manage"

  it_behaves_like "a badge action", not_allowed: "grant_not_allowed"

  it "grants the badge as the actor", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:user_badge_granted) { result = run_node }

    expect(result).to include(
      "user" => include("id" => user.id),
      "badge" => include("id" => badge.id, "grant_count" => 1),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(UserBadge.find_by(user:, badge:).granted_by).to eq(moderator)
    expect(staff_logs(:grant_badge).sole.acting_user).to eq(moderator)
    expect(user.notifications.where(notification_type: Notification.types[:granted_badge])).to exist
    expect(events.sole[:params]).to eq([badge.id, user.id, { acting_user: moderator }])
  end

  it "reports nothing changed for a badge the user already has" do
    BadgeGranter.grant(badge, user)

    expect(run_node).to include("changed" => false)
  end

  it "reports nothing changed when a concurrent request granted it first" do
    UserBadge.create!(badge:, user:, granted_by: admin, granted_at: Time.zone.now)
    BadgeGranter.stubs(:grant).raises(ActiveRecord::RecordNotUnique)

    expect(run_node).to include("changed" => false)
  end

  it "fails when the badge couldn't be granted" do
    BadgeGranter.stubs(:grant).raises(ActiveRecord::RecordNotUnique)

    expect { run_node }.to raise_error(
      DiscourseWorkflows::NodeError,
      badge_error("grant_failed", badge: badge.name, target: user.username),
    )
  end

  it "grants system badges" do
    expect(run_node(badge_id: Badge::BasicUser)).to include("changed" => true)
  end

  it "refuses disabled badges" do
    badge.update!(enabled: false)

    expect { run_node }.to raise_error(
      DiscourseWorkflows::NodeError,
      badge_error("badge_disabled", badge: badge.name),
    )
  end

  context "with a badge granted several times" do
    before { badge.update!(multiple_grant: true) }

    it "grants it for a post once", :aggregate_failures do
      expect(run_node(post_id: post.id.to_s)).to include("changed" => true)
      expect(run_node(post_id: post.id.to_s)).to include("changed" => false)
      expect(UserBadge.where(user:, badge:).pluck(:post_id)).to eq([post.id])
    end

    it "grants it again without a post" do
      run_node

      expect(run_node).to include("changed" => true)
    end
  end

  it "refuses a post the actor can't see" do
    pm = Fabricate(:private_message_post)

    expect { run_node(post_id: pm.id.to_s) }.to raise_error(
      DiscourseWorkflows::NodeError,
      badge_error("post_not_found", post_id: pm.id),
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::RevokeBadge::V1 do
  include_context "with a badge to manage"

  before { BadgeGranter.grant(badge, user) }

  it_behaves_like "a badge action", not_allowed: "revoke_not_allowed"

  it "revokes the badge as the actor, clearing a title it gave", :aggregate_failures do
    badge.update!(allow_title: true)
    user.update!(title: badge.name)

    result = nil
    events = DiscourseEvent.track_events(:user_badge_revoked) { result = run_node }

    expect(result).to include(
      "user" => include("id" => user.id),
      "badge" => include("id" => badge.id, "grant_count" => 0),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(UserBadge.where(user:, badge:)).to be_empty
    expect(user.reload.title).to be_nil
    expect(staff_logs(:revoke_badge).sole.acting_user).to eq(moderator)
    expect(events.sole[:params].sole).to include(acting_user: moderator)
  end

  it "reports nothing changed for a badge the user doesn't have" do
    UserBadge.where(user:, badge:).destroy_all

    expect(run_node).to include("changed" => false)
  end

  it "revokes disabled badges" do
    badge.update!(enabled: false)

    expect(run_node).to include("changed" => true)
  end

  it "reports nothing changed when a concurrent request revoked it first" do
    BadgeGranter.stubs(:revoke).raises(ActiveRecord::RecordNotFound)

    expect(run_node).to include("changed" => false)
  end

  context "with a badge granted several times" do
    fab!(:other_post) { Fabricate(:post, user:) }

    before do
      badge.update!(multiple_grant: true)
      UserBadge.where(user:, badge:).delete_all
      BadgeGranter.grant(badge, user, post_id: post.id)
      BadgeGranter.grant(badge, user, post_id: other_post.id)
    end

    it "revokes every grant" do
      events = DiscourseEvent.track_events(:user_badge_revoked) { run_node }

      expect(events.size).to eq(2)
      expect(UserBadge.where(user:, badge:)).to be_empty
    end

    it "revokes only the grant for a post", :aggregate_failures do
      expect(run_node(post_id: post.id.to_s)).to include("changed" => true)
      expect(UserBadge.where(user:, badge:).pluck(:post_id)).to eq([other_post.id])
      expect(run_node(post_id: post.id.to_s)).to include("changed" => false)
    end
  end
end
