# frozen_string_literal: true

require Rails.root.join("db/migrate/20261105165644_prune_push_subscriptions_per_user.rb")

RSpec.describe PrunePushSubscriptionsPerUser do
  fab!(:user)
  fab!(:other_user, :user)

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  describe "#up" do
    it "keeps only the ten newest subscriptions of each user" do
      subscriptions = Array.new(12) { Fabricate(:push_subscription, user: user) }
      other_subscriptions = Array.new(3) { Fabricate(:push_subscription, user: other_user) }

      described_class.new.up

      expect(PushSubscription.pluck(:id)).to match_array(
        (subscriptions.last(10) + other_subscriptions).map(&:id),
      )
    end
  end
end
