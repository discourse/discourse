# frozen_string_literal: true

describe DirectoryItem, type: :model do
  describe "Updating user directory with solutions count" do
    fab!(:user)
    fab!(:admin)

    fab!(:topic1) { Fabricate(:topic, archetype: "regular", user:) }
    fab!(:topic_post1) { Fabricate(:post, topic: topic1, user:, created_at: 10.years.ago) }

    fab!(:topic2) { Fabricate(:topic, archetype: "regular", user:) }
    fab!(:topic_post2) { Fabricate(:post, topic: topic2, user:, created_at: 10.years.ago) }

    fab!(:pm) { Fabricate(:topic, archetype: "private_message", user:, category_id: nil) }
    fab!(:pm_post) { Fabricate(:post, topic: pm, user:) }

    before { SiteSetting.solved_enabled = true }

    it "excludes PM post solutions from solutions" do
      DiscourseSolved.accept_answer!(topic_post1, admin)
      DiscourseSolved.accept_answer!(pm_post, admin)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        ).solutions,
      ).to eq(1)
    end

    it "excludes deleted posts from solutions" do
      DiscourseSolved.accept_answer!(topic_post1, admin)
      DiscourseSolved.accept_answer!(topic_post2, admin)
      topic_post2.update(deleted_at: Time.zone.now)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        ).solutions,
      ).to eq(1)
    end

    it "excludes deleted topics from solutions" do
      DiscourseSolved.accept_answer!(topic_post1, admin)
      DiscourseSolved.accept_answer!(topic_post2, admin)
      topic2.update(deleted_at: Time.zone.now)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        ).solutions,
      ).to eq(1)
    end

    it "excludes solutions for silenced users" do
      user.update(silenced_till: Time.zone.now + 1.day)

      DiscourseSolved.accept_answer!(topic_post1, admin)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        )&.solutions,
      ).to eq(nil)
    end

    it "excludes solutions for suspended users" do
      DiscourseSolved.accept_answer!(topic_post1, admin)
      user.update(suspended_till: Time.zone.now + 1.day)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:all],
        )&.solutions,
      ).to eq(0)
    end

    it "includes solutions for active users" do
      DiscourseSolved.accept_answer!(topic_post1, admin)

      DirectoryItem.refresh!

      expect(
        DirectoryItem.find_by(
          user_id: user.id,
          period_type: DirectoryItem.period_types[:daily],
        ).solutions,
      ).to eq(1)
    end

    context "when refreshing across dates" do
      it "updates the user's solution count from 1 to 0" do
        freeze_time 40.days.ago
        DiscourseSolved.accept_answer!(topic_post1, Discourse.system_user)

        DirectoryItem.refresh!

        expect(
          DirectoryItem.find_by(
            user_id: user.id,
            period_type: DirectoryItem.period_types[:monthly],
          ).solutions,
        ).to eq(1)

        unfreeze_time

        DirectoryItem.refresh!

        expect(
          DirectoryItem.find_by(
            user_id: user.id,
            period_type: DirectoryItem.period_types[:monthly],
          ).solutions,
        ).to eq(0)
      end
    end
  end
end
