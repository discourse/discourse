# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReviewableVoiceUser do
  fab!(:moderator)
  fab!(:flagger, :user)
  fab!(:flagged_user, :user)
  fab!(:room, :voice_room)
  fab!(:session) { Fabricate(:voice_session, room: room, user: flagged_user) }

  fab!(:reviewable) do
    reviewable =
      ReviewableVoiceUser.needs_review!(
        created_by: flagger,
        target: session,
        reviewable_by_moderator: true,
      )
    reviewable.update!(
      target_created_by: flagged_user,
      payload: {
        message: "Being disruptive",
        room_id: room.id,
        room_name: room.name,
        room_slug: room.slug,
      },
    )
    reviewable.add_score(flagger, ReviewableScore.types[:notify_moderators])
    reviewable
  end

  before { SiteSetting.voice_enabled = true }

  describe "#build_actions" do
    it "offers agree, suspend/silence, disagree and ignore to a moderator" do
      actions = reviewable.actions_for(moderator.guardian)

      expect(actions.to_a.map(&:server_action).map(&:to_sym)).to contain_exactly(
        :agree_and_keep,
        :agree_and_suspend,
        :agree_and_silence,
        :disagree,
        :ignore,
      )
    end

    it "offers no actions once the reviewable is handled" do
      reviewable.perform(moderator, :ignore)

      expect(reviewable.actions_for(moderator.guardian).to_a).to be_empty
    end
  end

  describe "#perform" do
    it "approves the reviewable and agrees with the flag on agree_and_keep" do
      reviewable.perform(moderator, :agree_and_keep)

      expect(reviewable.reload).to be_approved
      expect(reviewable.reviewable_scores.first).to be_agreed
    end

    it "rejects the reviewable and disagrees with the flag on disagree" do
      reviewable.perform(moderator, :disagree)

      expect(reviewable.reload).to be_rejected
      expect(reviewable.reviewable_scores.first).to be_disagreed
    end

    it "ignores the reviewable and the flag on ignore" do
      reviewable.perform(moderator, :ignore)

      expect(reviewable.reload).to be_ignored
      expect(reviewable.reviewable_scores.first).to be_ignored
    end
  end
end
