# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::Fbff do
  fab!(:date) { Date.new(2021).all_year }
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:bot)

  fab!(:topic)
  fab!(:post_1) { Fabricate(:post, topic: topic, user: user, created_at: random_datetime) }
  fab!(:post_2) do
    Fabricate(
      :post,
      topic: topic,
      user: other_user,
      created_at: random_datetime,
      reply_to_post_number: 1,
    )
  end
  fab!(:post_3) do
    Fabricate(
      :post,
      topic: topic,
      user: user,
      created_at: random_datetime,
      reply_to_post_number: post_2.post_number,
    )
  end

  describe ".post_query" do
    it "includes the correct posts for the time period based on replies between users" do
      expect(
        described_class.new(user: user, date: date).post_query(user, date).map(&:id),
      ).to match_array([post_2.id, post_3.id])
    end

    it "excludes posts by bot users" do
      post_2.update!(user: bot)

      expect(
        described_class.new(user: user, date: date).post_query(user, date).map(&:id),
      ).not_to include(post_2.id)
    end

    it "excludes posts by deactivated users" do
      user.deactivate(Discourse.system_user)

      expect(
        described_class.new(user: user, date: date).post_query(user, date).map(&:id),
      ).not_to include(post_2.id)
    end

    it "excludes posts by suspended users" do
      user.suspended_at = Time.now
      user.suspended_till = 200.years.from_now
      user.save!

      expect(
        described_class.new(user: user, date: date).post_query(user, date).map(&:id),
      ).not_to include(post_2.id)
    end

    it "excludes moderator action posts" do
      post_2.update!(post_type: Post.types[:moderator_action])

      expect(
        described_class.new(user: user, date: date).post_query(user, date).map(&:id),
      ).not_to include(post_2.id)
    end

    it "excludes posts not created in the time range of the report" do
      post_2.update!(created_at: 2.years.ago)

      expect(
        described_class.new(user: user, date: date).post_query(user, date).map(&:id),
      ).to be_empty
    end
  end

  describe ".like_query" do
    fab!(:like_1) do
      Fabricate(
        :user_action,
        action_type: UserAction::WAS_LIKED,
        acting_user: other_user,
        user: post_1.user,
        target_post: post_1,
        target_topic: post_1.topic,
        created_at: random_datetime,
      )
    end
    fab!(:like_2) do
      Fabricate(
        :user_action,
        action_type: UserAction::WAS_LIKED,
        acting_user: user,
        user: post_2.user,
        target_post: post_2,
        target_topic: post_2.topic,
        created_at: random_datetime,
      )
    end

    it "succesfully returns likes for the time period" do
      expect(described_class.new(user: user, date: date).like_query(date).map(&:id)).to match_array(
        [like_1.id, like_2.id],
      )
    end

    it "does not return likes outside the time period" do
      like_1.update!(created_at: 2.years.ago)

      expect(described_class.new(user: user, date: date).like_query(date).map(&:id)).not_to include(
        like_1.id,
      )
    end

    describe "user_id" do
      it "excludes likes from deactivated users" do
        other_user.deactivate(Discourse.system_user)

        expect(
          described_class.new(user: user, date: date).like_query(date).map(&:id),
        ).not_to include(like_1.id)
      end

      it "excludes likes from suspended users" do
        other_user.suspended_at = Time.now
        other_user.suspended_till = 200.years.from_now
        other_user.save!

        expect(
          described_class.new(user: user, date: date).like_query(date).map(&:id),
        ).not_to include(like_1.id)
      end

      it "excludes likes from bot users" do
        post_1.update!(user: bot)
        like_1.update!(acting_user: bot)

        expect(
          described_class.new(user: user, date: date).like_query(date).map(&:id),
        ).not_to include(like_1.id)
      end
    end

    describe "acting_user_id" do
      it "excludes likes from deactivated users" do
        user.deactivate(Discourse.system_user)

        expect(
          described_class.new(user: user, date: date).like_query(date).map(&:id),
        ).not_to include(like_2.id)
      end

      it "excludes likes from suspended users" do
        user.suspended_at = Time.now
        user.suspended_till = 200.years.from_now
        user.save!

        expect(
          described_class.new(user: user, date: date).like_query(date).map(&:id),
        ).not_to include(like_2.id)
      end

      it "excludes likes from bot users" do
        post_2.update!(user: bot)
        like_2.update!(acting_user: bot)

        expect(
          described_class.new(user: user, date: date).like_query(date).map(&:id),
        ).not_to include(like_2.id)
      end
    end
  end
end
