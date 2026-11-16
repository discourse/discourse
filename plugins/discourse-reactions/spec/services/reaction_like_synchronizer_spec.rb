# frozen_string_literal: true

RSpec.describe DiscourseReactions::ReactionLikeSynchronizer do
  let!(:user) { Fabricate(:user) }
  let!(:post) { Fabricate(:post) }
  let!(:post_2) { Fabricate(:post) }

  before do
    SiteSetting.discourse_reactions_like_sync_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions += "heart|clap|+1|-1"
    SiteSetting.discourse_reactions_excluded_from_like = "clap|-1"

    UserActionManager.enable
  end

  let!(:topic_user) { Fabricate(:topic_user, user: user, topic: post.topic) }
  let!(:topic_user_2) { Fabricate(:topic_user, user: user, topic: post_2.topic) }

  # This and reaction_user_2 use the ReactionManager so the proper PostActionCreator
  # records are created, rather than building this all manually.
  let!(:reaction_user) do
    DiscourseReactions::ReactionManager.new(reaction_value: "+1", user: user, post: post).toggle!
    DiscourseReactions::ReactionUser.find_by(user: user, post: post)
  end

  let!(:reaction_user_2) do
    DiscourseReactions::ReactionManager.new(
      reaction_value: "clap",
      user: user,
      post: post_2,
    ).toggle!
    DiscourseReactions::ReactionUser.find_by(user: user, post: post_2)
  end

  it "does nothing if discourse_reactions_like_sync_enabled is false" do
    SiteSetting.discourse_reactions_like_sync_enabled = false
    SiteSetting.discourse_reactions_excluded_from_like = ""

    expect { described_class.sync! }.not_to change { PostAction.count }
  end

  describe "when reactions are added to the exclusion list" do
    before do
      SiteSetting.discourse_reactions_excluded_from_like += "|+1" # +1 added
    end

    it "trashes the likes and recalculates derived data" do
      post_action = reaction_user.post_action_like

      expect { described_class.sync! }.to change { UserAction.count }.by(-2)

      expect(post_action.reload.trashed?).to eq(true)
      expect(post.reload).to have_attributes(like_count: 0, like_score: 0)
      expect(post.topic.reload.like_count).to eq(0)
      expect(topic_user.reload.liked).to eq(false)
      expect(user.user_stat.reload.likes_given).to eq(0)
      expect(post.user.user_stat.reload.likes_received).to eq(0)
      expect(GivenDailyLike.exists?(user:)).to eq(false)
    end

    it "does not re-trash already trashed likes" do
      post_action = reaction_user.post_action_like
      described_class.sync!
      post_action.update_columns(deleted_at: 1.day.ago)

      expect { described_class.sync! }.not_to change { post_action.reload.deleted_at }
    end
  end

  describe "when reactions are removed from the exclusion list" do
    before do
      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
    end

    it "creates the likes and recalculates derived data" do
      SiteSetting.max_likes_per_day = 2

      stub_const(described_class, :BATCH_SIZE, 1) { described_class.sync! }

      expect(reaction_user_2.reload.post_action_like).to be_present
      expect(
        UserAction.where(target_post_id: post_2.id, target_topic_id: post_2.topic_id).pluck(
          :action_type,
          :user_id,
          :acting_user_id,
        ),
      ).to contain_exactly(
        [UserAction::LIKE, user.id, user.id],
        [UserAction::WAS_LIKED, post_2.user_id, user.id],
      )
      expect(post_2.reload).to have_attributes(like_count: 1, like_score: 1)
      expect(post_2.topic.reload.like_count).to eq(1)
      expect(topic_user_2.reload.liked).to eq(true)
      expect(user.user_stat.reload.likes_given).to eq(2)
      expect(post_2.user.user_stat.reload.likes_received).to eq(1)
      expect(GivenDailyLike.find_by(user:, given_date: Time.zone.today)).to have_attributes(
        likes_given: 2,
        limit_reached: true,
      )
    end

    it "creates the likes when the user has another post action on the post" do
      Fabricate(
        :post_action,
        user:,
        post: post_2,
        post_action_type_id: PostActionType.types[:off_topic],
      )

      described_class.sync!

      expect(reaction_user_2.reload.post_action_like).to be_present
    end

    it "recovers likes it trashed and recalculates derived data" do
      SiteSetting.discourse_reactions_excluded_from_like = "-1|+1"
      described_class.sync!
      SiteSetting.discourse_reactions_excluded_from_like = "-1"

      expect { described_class.sync! }.to change { UserAction.count }.by(2)

      expect(reaction_user.reload.post_action_like).to be_present
      expect(post.reload.like_count).to eq(1)
    end

    it "recovers likes the user trashed by switching to an excluded reaction" do
      DiscourseReactions::ReactionManager.new(reaction_value: "-1", user:, post:).toggle!
      SiteSetting.discourse_reactions_excluded_from_like = ""

      described_class.sync!

      expect(PostAction.where(user:, post:).count).to eq(1)
    end

    it "ignores deleted posts" do
      admin = Fabricate(:admin)
      PostDestroyer.new(admin, post).destroy
      PostDestroyer.new(admin, post_2).destroy

      described_class.sync!

      expect(
        PostAction.where(user:, post_action_type_id: PostActionType::LIKE_POST_ACTION_ID),
      ).to be_empty
    end

    it "never violates the uniqueness of likes" do
      [post, post_2, post_2].each do |liked_post|
        PostAction.new(
          user:,
          post: liked_post,
          post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          deleted_at: 1.day.ago,
        ).save!(validate: false)
      end

      expect { described_class.sync! }.not_to raise_error
      expect(PostAction.where(user:, post: [post, post_2]).group(:post_id).count).to eq(
        post.id => 1,
        post_2.id => 1,
      )
    end

    it "never creates or recovers self-likes" do
      SiteSetting.discourse_reactions_excluded_from_like = "-1|+1|clap"
      described_class.sync!
      Post.where(id: [post.id, post_2.id]).update_all(user_id: user.id)
      SiteSetting.discourse_reactions_excluded_from_like = "-1"

      described_class.sync!

      expect(
        PostAction.where(user:, post_action_type_id: PostActionType::LIKE_POST_ACTION_ID),
      ).to be_empty
    end

    it "ignores private message likes in user stats" do
      pm_post = Fabricate(:private_message_post, user: post_2.user, recipient: user)
      PostActionCreator.like(user, pm_post)

      described_class.sync!

      expect(user.user_stat.reload.likes_given).to eq(2)
      expect(post_2.user.user_stat.reload.likes_received).to eq(1)
    end

    it "excludes whispers and deleted posts from topic like counts" do
      post_2.update_columns(post_type: Post.types[:whisper])
      Fabricate(:post, topic: post_2.topic, like_count: 1, deleted_at: Time.zone.now)

      described_class.sync!

      expect(post_2.topic.reload.like_count).to eq(0)
    end

    it "ignores posts without an author" do
      post_2.update_columns(user_id: nil)

      expect { described_class.sync! }.not_to change { UserAction.count }
      expect(reaction_user_2.reload.post_action_like).to be_nil
    end
  end
end
