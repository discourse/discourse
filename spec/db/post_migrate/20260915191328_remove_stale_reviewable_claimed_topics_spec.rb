# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20260915191328_remove_stale_reviewable_claimed_topics.rb")

RSpec.describe RemoveStaleReviewableClaimedTopics do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  fab!(:moderator)
  fab!(:inherited_topic, :topic)
  fab!(:reopened_topic, :topic)
  fab!(:resolved_topic, :topic)
  fab!(:live_topic, :topic)
  fab!(:automatic_topic, :topic)

  it "removes manual claims whose topic has no reviewable pending since before the claim" do
    reopened_reviewable =
      freeze_time(3.days.ago) do
        Fabricate(:reviewable_queued_post, topic: inherited_topic, status: :approved)
        Fabricate(:reviewable_queued_post, topic: resolved_topic, status: :approved)
        Fabricate(:reviewable_flagged_post, topic: reopened_topic)
      end

    freeze_time(2.days.ago) do
      [inherited_topic, reopened_topic, resolved_topic].each do |topic|
        Fabricate(:reviewable_claimed_topic, topic:, user: moderator)
      end
    end

    freeze_time(1.day.ago) do
      Fabricate(:reviewable_flagged_post, topic: inherited_topic)
      reopened_reviewable.log_history(:transitioned, moderator)
    end

    described_class.new.up

    expect(ReviewableClaimedTopic.all).to be_empty
  end

  it "keeps manual claims on reviewables pending since before the claim, and automatic claims" do
    freeze_time(2.days.ago) { Fabricate(:reviewable_flagged_post, topic: live_topic) }

    live_claim =
      freeze_time(1.day.ago) do
        Fabricate(:reviewable_claimed_topic, topic: live_topic, user: moderator)
      end
    automatic_claim =
      Fabricate(:reviewable_claimed_topic, topic: automatic_topic, user: moderator, automatic: true)

    described_class.new.up

    expect(ReviewableClaimedTopic.all).to contain_exactly(live_claim, automatic_claim)
  end
end
