# frozen_string_literal: true

RSpec.describe DiscourseReactions::ReactionLikeSynchronizer do
  let!(:user) { Fabricate(:user) }
  let!(:post) { Fabricate(:post, like_count: 1) }
  let!(:post_2) { Fabricate(:post, like_count: 0) }

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
    @reaction_plus_one = DiscourseReactions::Reaction.find_by(reaction_value: "+1", post: post)
    DiscourseReactions::ReactionUser.find_by(user: user, post: post, reaction: @reaction_plus_one)
  end

  let!(:reaction_user_2) do
    DiscourseReactions::ReactionManager.new(
      reaction_value: "clap",
      user: user,
      post: post_2,
    ).toggle!
    @reaction_clap = DiscourseReactions::Reaction.find_by(reaction_value: "clap", post: post_2)
    DiscourseReactions::ReactionUser.find_by(user: user, post: post_2, reaction: @reaction_clap)
  end

  it "does nothing if discourse_reactions_like_sync_enabled is false" do
    DB.expects(:exec).never
    SiteSetting.discourse_reactions_like_sync_enabled = false
    expect { described_class.sync! }.not_to change { PostAction.count }
  end

  describe "when reactions are added to the exclusion list" do
    before do
      SiteSetting.discourse_reactions_excluded_from_like += "|+1" # +1 added
    end

    it "trashes PostAction records" do
      post_action_id = reaction_user.post_action_like.id
      expect(reaction_user.post_action_like).to be_present
      expect { described_class.sync! }.to change { PostAction.count }.by(-1)
      expect(reaction_user.reload.post_action_like).to be_nil
      expect(PostAction.with_deleted.find_by(id: post_action_id).deleted_at).to be_present
    end

    it "removes UserAction records for LIKED and WAS_LIKED" do
      expect { described_class.sync! }.to change { UserAction.count }.by(-2)
    end

    it "updates the like_count on the associated Post records" do
      expect(post.reload.like_count).to eq(1)
      expect(post_2.reload.like_count).to eq(0)
      described_class.sync!
      expect(post.reload.like_count).to eq(0)
      expect(post_2.reload.like_count).to eq(0)
    end

    it "updates the like_count on the associated Topic records" do
      expect(post.topic.reload.like_count).to eq(1)
      expect(post_2.topic.reload.like_count).to eq(0)
      described_class.sync!
      expect(post.topic.reload.like_count).to eq(0)
      expect(post_2.topic.reload.like_count).to eq(0)
    end

    it "updates the liked column on TopicUser for associated topic and users" do
      expect(post.topic.topic_users.find_by(user: user).liked).to eq(true)
      expect(post_2.topic.topic_users.find_by(user: user).liked).to eq(false)
      described_class.sync!
      expect(post.topic.topic_users.find_by(user: user).liked).to eq(false)
      expect(post_2.topic.topic_users.find_by(user: user).liked).to eq(false)
    end

    it "updates the UserStat likes_given and likes_received columns" do
      expect(user.user_stat.reload.likes_given).to eq(1)
      expect(post.user.user_stat.reload.likes_received).to eq(1)
      described_class.sync!
      expect(user.user_stat.reload.likes_given).to eq(0)
      expect(post.user.user_stat.reload.likes_received).to eq(0)
    end

    it "updates/recalculates the GivenDailyLike table likes_given on all given_date days and deletes records where likes_given would be 0" do
      expect(
        GivenDailyLike.exists?(user: user, given_date: Time.now.to_date, likes_given: 1),
      ).to eq(true)
      described_class.sync!
      expect(GivenDailyLike.exists?(user: user, given_date: Time.now.to_date)).to eq(false)
    end
  end

  describe "when reactions are removed from the exclusion list" do
    it "creates PostAction records" do
      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
      expect(reaction_user_2.post_action_like).to be_nil
      expect { described_class.sync! }.to change { PostAction.count }.by(1)
      expect(reaction_user_2.reload.post_action_like).to be_present
    end

    it "updates existing trashed PostUpdate records to recover them" do
      trashed_post_action =
        Fabricate(
          :post_action,
          post: reaction_user_2.post,
          user: reaction_user_2.user,
          post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
        )
      trashed_post_action.trash!(Fabricate(:user))
      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
      expect { described_class.sync! }.to change { PostAction.count }.by(1)
      expect(trashed_post_action.reload.trashed?).to eq(false)
    end

    it "creates UserAction records for LIKED and WAS_LIKED" do
      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
      expect { described_class.sync! }.to change { UserAction.count }.by(2)
      expect(
        UserAction.exists?(
          action_type: UserAction::LIKE,
          user_id: reaction_user_2.post_action_like.user_id,
          acting_user_id: reaction_user_2.post_action_like.user_id,
          target_post_id: reaction_user_2.post_action_like.post_id,
          target_topic_id: reaction_user_2.post.topic_id,
        ),
      ).to eq(true)
      expect(
        UserAction.exists?(
          action_type: UserAction::WAS_LIKED,
          user_id: reaction_user_2.post.user_id,
          acting_user_id: reaction_user_2.post_action_like.user_id,
          target_post_id: reaction_user_2.post_action_like.post_id,
          target_topic_id: reaction_user_2.post.topic_id,
        ),
      ).to eq(true)
    end

    it "skips UserAction records where the post has a null user" do
      reaction_user_2.post.update_columns(user_id: nil)
      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
      expect { described_class.sync! }.not_to change { UserAction.count }
    end

    it "if no reactions are excluded from like it adds post actions for ones previously excluded" do
      SiteSetting.discourse_reactions_excluded_from_like = ""
      expect(reaction_user_2.post_action_like).to be_nil
      expect { described_class.sync! }.to change { PostAction.count }.by(1)
      expect(reaction_user_2.reload.post_action_like).to be_present
    end

    it "updates the like_count on the associated Post records" do
      expect(post.reload.like_count).to eq(1)
      expect(post_2.reload.like_count).to eq(0)

      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
      described_class.sync!
      expect(post.reload.like_count).to eq(1)
      expect(post_2.reload.like_count).to eq(1)
    end

    it "updates the like_count on the associated Topic records" do
      expect(post.topic.reload.like_count).to eq(1)
      expect(post_2.topic.reload.like_count).to eq(0)

      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
      described_class.sync!
      expect(post.topic.reload.like_count).to eq(1)
      expect(post_2.topic.reload.like_count).to eq(1)
    end

    it "updates the liked column on TopicUser for associated topic and users" do
      expect(post.topic.topic_users.find_by(user: user).liked).to eq(true)
      expect(post_2.topic.topic_users.find_by(user: user).liked).to eq(false)

      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
      described_class.sync!
      expect(post.topic.topic_users.find_by(user: user).liked).to eq(true)
      expect(post_2.topic.topic_users.find_by(user: user).liked).to eq(true)
    end

    it "updates the UserStat likes_given and likes_received columns" do
      expect(user.user_stat.reload.likes_given).to eq(1)
      expect(post.user.user_stat.reload.likes_received).to eq(1)
      expect(post_2.user.user_stat.reload.likes_received).to eq(0)

      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
      described_class.sync!
      expect(user.user_stat.reload.likes_given).to eq(2)
      expect(post.user.user_stat.reload.likes_received).to eq(1)
      expect(post_2.user.user_stat.reload.likes_received).to eq(1)
    end

    it "updates/recalculates the GivenDailyLike table likes_given on all given_date days and deletes records where likes_given would be 0" do
      SiteSetting.discourse_reactions_excluded_from_like = "-1" # clap removed
      expect { described_class.sync! }.to change {
        GivenDailyLike.find_by(user: user, given_date: Time.now.to_date).likes_given
      }.to 2
    end
  end
end
