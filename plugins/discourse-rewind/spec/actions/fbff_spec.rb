# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::Fbff do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:topic)
  fab!(:post_1) { Fabricate(:post, topic:, user:, created_at: random_datetime) }
  fab!(:post_2) do
    Fabricate(
      :post,
      topic:,
      user: other_user,
      created_at: random_datetime,
      reply_to_post_number: post_1.post_number,
    )
  end
  fab!(:post_3) do
    Fabricate(
      :post,
      topic:,
      user:,
      created_at: random_datetime,
      reply_to_post_number: post_2.post_number,
    )
  end
  fab!(:restricted_category) { Fabricate(:private_category, group: Fabricate(:group)) }

  describe ".call" do
    it "ranks a reply higher than a like" do
      liker = Fabricate(:user)
      9.times do
        liked_post = Fabricate(:post, user:, created_at: random_datetime)
        Fabricate(
          :user_action,
          action_type: UserAction::WAS_LIKED,
          acting_user: liker,
          user:,
          target_post: liked_post,
          target_topic: liked_post.topic,
          created_at: random_datetime,
        )
      end

      expect(call_report[:data][:fbff][:id]).to eq(other_user.id)
    end

    context "when there are only likes" do
      fab!(:friend, :user)

      before { [post_2, post_3].each(&:trash!) }

      def like(acting_user:, liked_user:)
        liked_post = Fabricate(:post, user: liked_user, created_at: random_datetime)
        Fabricate(
          :user_action,
          action_type: UserAction::WAS_LIKED,
          acting_user:,
          user: liked_user,
          target_post: liked_post,
          target_topic: liked_post.topic,
          created_at: random_datetime,
        )
      end

      it "counts likes the user gave" do
        like(acting_user: user, liked_user: friend)

        expect(call_report[:data][:fbff][:id]).to eq(friend.id)
      end

      it "counts likes the user received" do
        like(acting_user: friend, liked_user: user)

        expect(call_report[:data][:fbff][:id]).to eq(friend.id)
      end
    end

    context "when the only friend exchanges likes and replies with the user" do
      before do
        [[other_user, user, post_1], [user, other_user, post_2]].each do |acting_user, liked, post|
          Fabricate(
            :user_action,
            action_type: UserAction::WAS_LIKED,
            acting_user:,
            user: liked,
            target_post: post,
            target_topic: topic,
            created_at: random_datetime,
          )
        end
      end

      it "ignores them when they are not active" do
        other_user.deactivate(Discourse.system_user)

        expect(call_report).to be_nil
      end

      it "ignores them when they are muted" do
        Fabricate(:muted_user, user:, muted_user: other_user)

        expect(call_report).to be_nil
      end

      it "ignores them when they are ignored" do
        Fabricate(:ignored_user, user:, ignored_user: other_user)

        expect(call_report).to be_nil
      end
    end
  end

  describe "#post_query" do
    subject(:post_ids) { described_class.new(user:, date:).post_query.map(&:id) }

    it "returns the replies between users" do
      expect(post_ids).to contain_exactly(post_2.id, post_3.id)
    end

    it "excludes replies to the user's own posts" do
      post_2.update!(user:)

      expect(post_ids).to be_empty
    end

    it "excludes replies outside the year" do
      post_2.update!(created_at: 2.years.ago)

      expect(post_ids).to be_empty
    end

    it "excludes whispers when the user is a whisperer" do
      whisperers = Fabricate(:group)
      whisperers.add(user)
      SiteSetting.whispers_allowed_groups = whisperers.id.to_s
      post_2.update!(post_type: Post.types[:whisper])

      expect(post_ids).to be_empty
    end

    it "excludes hidden posts" do
      post_2.update!(hidden: true)

      expect(post_ids).to be_empty
    end

    it "excludes deleted posts" do
      post_2.trash!

      expect(post_ids).to be_empty
    end

    it "excludes topics that are not publicly visible" do
      topic.update!(category: restricted_category)

      expect(post_ids).to be_empty
    end
  end

  describe "#like_query" do
    subject(:like_ids) { described_class.new(user:, date:).like_query.map(&:id) }

    fab!(:like_1) do
      Fabricate(
        :user_action,
        action_type: UserAction::WAS_LIKED,
        acting_user: other_user,
        user:,
        target_post: post_1,
        target_topic: topic,
        created_at: random_datetime,
      )
    end
    fab!(:like_2) do
      Fabricate(
        :user_action,
        action_type: UserAction::WAS_LIKED,
        acting_user: user,
        user: other_user,
        target_post: post_2,
        target_topic: topic,
        created_at: random_datetime,
      )
    end

    it "returns the likes between users" do
      expect(like_ids).to contain_exactly(like_1.id, like_2.id)
    end

    it "excludes likes outside the year" do
      like_1.update!(created_at: 2.years.ago)

      expect(like_ids).to contain_exactly(like_2.id)
    end

    it "excludes likes on whispers and hidden posts" do
      post_1.update!(post_type: Post.types[:whisper])
      post_2.update!(hidden: true)

      expect(like_ids).to be_empty
    end

    it "excludes topics that are not publicly visible" do
      topic.update!(category: restricted_category)

      expect(like_ids).to be_empty
    end
  end
end
