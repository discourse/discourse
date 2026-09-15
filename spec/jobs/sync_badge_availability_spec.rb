# frozen_string_literal: true

RSpec.describe Jobs::SyncBadgeAvailability do
  describe ".enqueue" do
    it "coalesces per plugin and permits another request once work starts" do
      expect do
        2.times do
          described_class.enqueue("first")
          described_class.enqueue("second")
        end
      end.to change { described_class.jobs.size }.by(2)

      described_class.new.execute(plugin_name: "first")

      expect do
        described_class.enqueue("first")
        described_class.enqueue("second")
      end.to change { described_class.jobs.size }.by(1)
    end

    it "permits retrying when enqueueing fails" do
      described_class.stubs(:client_push).raises(Redis::CannotConnectError)

      expect { described_class.enqueue }.to raise_error(Redis::CannotConnectError)

      described_class.unstub(:client_push)

      expect { described_class.enqueue }.to change { described_class.jobs.size }.by(1)
    end
  end

  describe "#execute" do
    it "backfills only available query badges for the changed plugin" do
      plugin = Plugin::Instance.new(Plugin::Metadata.parse("# name: example"))
      plugins = Discourse.plugins_by_name.merge(plugin.name => plugin)
      Discourse.stubs(:plugins_by_name).returns(plugins)
      badge = Fabricate(:badge, plugin_name: plugin.name, query: "SELECT 1")
      disabled_badge =
        Fabricate(:badge, plugin_name: plugin.name, query: "SELECT 1", enabled: false)
      instant_badge = Fabricate(:badge, plugin_name: plugin.name)
      unrelated_badge = Fabricate(:badge, query: "SELECT 1")

      described_class.new.execute(plugin_name: plugin.name)

      expect_job_enqueued(job: :backfill_badge, args: { badge_id: badge.id })
      [disabled_badge, instant_badge, unrelated_badge].each do |other|
        expect_not_enqueued_with(job: :backfill_badge, args: { badge_id: other.id })
      end
    end

    it "repairs counts and featured ranks after plugin removal and installation, preserving awards" do
      user = Fabricate(:user)
      badge = Fabricate(:badge)
      other_badge = Fabricate(:badge)
      award = BadgeGranter.grant(badge, user)
      other_award = BadgeGranter.grant(other_badge, user)
      award.update_columns(featured_rank: 1)
      other_award.update_columns(featured_rank: 2)
      badge.update_column(:plugin_name, "removed-plugin")

      described_class.new.execute({})

      expect(user.user_stat.reload.distinct_badge_count).to eq(1)
      expect(other_award.reload.featured_rank).to eq(1)
      expect(award.reload.featured_rank).to eq(2)
      expect(badge.reload.enabled).to eq(true)

      plugin = Plugin::Instance.new(Plugin::Metadata.parse("# name: removed-plugin"))
      plugins = Discourse.plugins_by_name.merge(plugin.name => plugin)
      Discourse.stubs(:plugins_by_name).returns(plugins)

      described_class.new.execute({})

      expect(user.user_stat.reload.distinct_badge_count).to eq(2)
      expect(UserBadge.where(user: user)).to contain_exactly(award, other_award)
    end
  end
end
