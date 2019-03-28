require 'rails_helper'

describe PostActionCreator do
  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post) }
  let(:like_type_id) { PostActionType.types[:like] }

  describe "rate limits" do
    before do
      RateLimiter.clear_all!
      RateLimiter.enable
    end

    it "limits redo/undo" do
      PostActionCreator.like(user, post)
      PostActionDestroyer.destroy(user, post, :like)
      PostActionCreator.like(user, post)
      PostActionDestroyer.destroy(user, post, :like)

      expect {
        PostActionCreator.like(user, post)
      }.to raise_error(RateLimiter::LimitExceeded)
    end
  end

  describe "messaging" do

    it "doesn't generate title longer than 255 characters" do
      topic = Fabricate(:topic, title: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc sit amet rutrum neque. Pellentesque suscipit vehicula facilisis. Phasellus lacus sapien, aliquam nec convallis sit amet, vestibulum laoreet ante. Curabitur et pellentesque tortor. Donec non.")
      post = Fabricate(:post, topic: topic)

      expect(PostActionCreator.notify_user(user, post, "WAT")).to be_success
    end

    it "creates a pm to mods if selected" do
      result = PostActionCreator.notify_moderators(user, post, "this is my special message")
      expect(result).to be_success
      post_action = result.post_action
      expect(post_action.related_post).to be_present
      expect(post_action.related_post.raw).to include("this is my special message")
    end

    it "sends an pm to user if selected" do
      result = PostActionCreator.notify_user(user, post, "another special message")
      expect(result).to be_success
      post_action = result.post_action
      expect(post_action.related_post).to be_present
      expect(post_action.related_post.raw).to include("another special message")
    end
  end

  describe 'perform' do
    it 'creates a post action' do
      result = PostActionCreator.new(user, post, like_type_id).perform
      expect(result.success).to eq(true)
      expect(result.post_action).to be_present
      expect(result.post_action.user).to eq(user)
      expect(result.post_action.post).to eq(post)
      expect(result.post_action.post_action_type_id).to eq(like_type_id)
    end

    it 'does not create an invalid post action' do
      result = PostActionCreator.new(user, nil, like_type_id).perform
      expect(result.failed?).to eq(true)
    end
  end

  context "flags" do
    it "will create a reviewable if one does not exist" do
      result = PostActionCreator.create(user, post, :inappropriate)
      expect(result.success?).to eq(true)

      reviewable = result.reviewable
      expect(reviewable).to be_pending
      expect(reviewable.created_by).to eq(user)
      expect(reviewable.type).to eq("ReviewableFlaggedPost")
      expect(reviewable.target_created_by_id).to eq(post.user_id)

      expect(reviewable.reviewable_scores.count).to eq(1)
      score = reviewable.reviewable_scores.find_by(user: user)
      expect(score).to be_present
      expect(score.reviewed_by).to be_blank
      expect(score.reviewed_at).to be_blank
    end

    context "existing reviewable" do
      let!(:reviewable) {
        PostActionCreator.create(Fabricate(:user), post, :inappropriate).reviewable
      }

      it "appends to an existing reviewable if exists" do
        result = PostActionCreator.create(user, post, :inappropriate)
        expect(result.success?).to eq(true)

        expect(result.reviewable).to eq(reviewable)
        expect(reviewable.reviewable_scores.count).to eq(2)
        score = reviewable.reviewable_scores.find_by(user: user)
        expect(score).to be_present
        expect(score.reviewed_by).to be_blank
        expect(score.reviewed_at).to be_blank
      end
    end
  end
end
