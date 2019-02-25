require 'rails_helper'
require_dependency 'validators/post_validator'

describe Validators::PostValidator do
  let(:post) { build(:post, topic: Fabricate(:topic)) }
  let(:validator) { Validators::PostValidator.new({}) }

  context "#post_body_validator" do
    it 'should not allow a post with an empty raw' do
      post.raw = ""
      validator.post_body_validator(post)
      expect(post.errors).to_not be_empty
    end

    context "when empty raw can bypass validation" do
      let(:validator) { Validators::PostValidator.new(skip_post_body: true) }

      it "should be allowed for empty raw based on site setting" do
        post.raw = ""
        validator.post_body_validator(post)
        expect(post.errors).to be_empty
      end
    end

    describe "when post's topic is a PM between a human and a non human user" do
      let(:robot) { Fabricate(:user, id: -3) }
      let(:user) { Fabricate(:user) }

      let(:topic) do
        Fabricate(:private_message_topic, topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: robot),
          Fabricate.build(:topic_allowed_user, user: user)
        ])
      end

      it 'should allow a post with an empty raw' do
        post = Fabricate.build(:post, topic: topic)
        post.raw = ""
        validator.post_body_validator(post)

        expect(post.errors).to be_empty
      end
    end
  end

  context "stripped_length" do
    it "adds an error for short raw" do
      post.raw = "abc"
      validator.stripped_length(post)
      expect(post.errors.count).to eq(1)
    end

    it "adds no error for long raw" do
      post.raw = "this is a long topic body testing 123"
      validator.stripped_length(post)
      expect(post.errors.count).to eq(0)
    end
  end

  context "too_many_posts" do
    it "should be invalid when the user has posted too much" do
      post.user.expects(:posted_too_much_in_topic?).returns(true)
      validator.max_posts_validator(post)
      expect(post.errors.count).to be > 0
    end

    it "should be allowed to edit when the user has posted too much" do
      post.user.stubs(:posted_too_much_in_topic?).returns(true)
      post.expects(:new_record?).returns(false)
      validator.max_posts_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be valid when the user hasn't posted too much" do
      post.user.expects(:posted_too_much_in_topic?).returns(false)
      validator.max_posts_validator(post)
      expect(post.errors.count).to be(0)
    end
  end

  context "too_many_mentions" do
    before do
      SiteSetting.newuser_max_mentions_per_post = 2
      SiteSetting.max_mentions_per_post = 3
    end

    it "should be invalid when new user exceeds max mentions limit" do
      post.acting_user = build(:newuser)
      post.expects(:raw_mentions).returns(['jake', 'finn', 'jake_old'])
      validator.max_mention_validator(post)
      expect(post.errors.count).to be > 0
    end

    it "should be invalid when leader user exceeds max mentions limit" do
      post.acting_user = build(:trust_level_4)
      post.expects(:raw_mentions).returns(['jake', 'finn', 'jake_old', 'jake_new'])
      validator.max_mention_validator(post)
      expect(post.errors.count).to be > 0
    end

    it "should be valid when new user does not exceed max mentions limit" do
      post.acting_user = build(:newuser)
      post.expects(:raw_mentions).returns(['jake', 'finn'])
      validator.max_mention_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be valid when new user exceeds max mentions limit in PM" do
      post.acting_user = build(:newuser)
      post.topic.expects(:private_message?).returns(true)
      post.expects(:raw_mentions).returns(['jake', 'finn', 'jake_old'])
      validator.max_mention_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be valid when leader user does not exceed max mentions limit" do
      post.acting_user = build(:trust_level_4)
      post.expects(:raw_mentions).returns(['jake', 'finn', 'jake_old'])
      validator.max_mention_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be valid for moderator in all cases" do
      post.acting_user = build(:moderator)
      post.expects(:raw_mentions).never
      validator.max_mention_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be valid for admin in all cases" do
      post.acting_user = build(:admin)
      post.expects(:raw_mentions).never
      validator.max_mention_validator(post)
      expect(post.errors.count).to be(0)
    end
  end

  context "too_many_images" do
    before do
      SiteSetting.min_trust_to_post_images = 0
      SiteSetting.newuser_max_images = 2
    end

    it "should be invalid when new user exceeds max mentions limit" do
      post.acting_user = build(:newuser)
      post.expects(:image_count).returns(3)
      validator.max_images_validator(post)
      expect(post.errors.count).to be > 0
    end

    it "should be valid when new user does not exceed max mentions limit" do
      post.acting_user = build(:newuser)
      post.expects(:image_count).returns(2)
      validator.max_images_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be invalid when user trust level is not sufficient" do
      SiteSetting.min_trust_to_post_images = 4
      post.acting_user = build(:leader)
      post.expects(:image_count).returns(2)
      validator.max_images_validator(post)
      expect(post.errors.count).to be > 0
    end

    it "should be valid for moderator in all cases" do
      post.acting_user = build(:moderator)
      post.expects(:image_count).never
      validator.max_images_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be valid for admin in all cases" do
      post.acting_user = build(:admin)
      post.expects(:image_count).never
      validator.max_images_validator(post)
      expect(post.errors.count).to be(0)
    end
  end

  context "invalid post" do
    it "should be invalid" do
      validator.validate(post)
      expect(post.errors.count).to be > 0
    end
  end

  describe "unique_post_validator" do
    before do
      SiteSetting.unique_posts_mins = 5
    end

    context "post is unique" do
      before do
        post.stubs(:matches_recent_post?).returns(false)
      end

      it "should not add an error" do
        validator.unique_post_validator(post)
        expect(post.errors.count).to eq(0)
      end
    end

    context "post is not unique" do
      before do
        post.stubs(:matches_recent_post?).returns(true)
      end

      it "should add an error" do
        validator.unique_post_validator(post)
        expect(post.errors.count).to be > 0
      end

      it "should not add an error if post.skip_unique_check is true" do
        post.skip_unique_check = true
        validator.unique_post_validator(post)
        expect(post.errors.count).to eq(0)
      end
    end
  end

  context "force_edit_last_validator" do

    let(:user) { Fabricate(:user) }
    let(:other_user) { Fabricate(:user) }
    let(:topic) { Fabricate(:topic) }

    before do
      SiteSetting.max_consecutive_replies = 2
    end

    it "should always allow original poster to post" do
      [user, user, user, other_user, user, user, user].each_with_index do |u, i|
        post = Post.new(user: u, topic: topic, raw: "post number #{i}")
        validator.force_edit_last_validator(post)
        expect(post.errors.count).to eq(0)
        post.save!
      end
    end

    it "should not allow posting more than 2 consecutive replies" do
      Post.create!(user: user, topic: topic, raw: "post number 2", post_number: 2)
      Post.create!(user: user, topic: topic, raw: "post number 3", post_number: 3)
      Post.create!(user: other_user, topic: topic, raw: "post number 1", post_number: 1)

      post = Post.new(user: user, topic: topic, raw: "post number 4", post_number: 4)
      validator.force_edit_last_validator(post)
      expect(post.errors.count).to eq(1)
    end

    it "should always allow editing" do
      post = Fabricate(:post, user: user, topic: topic)
      post = Fabricate(:post, user: user, topic: topic)

      revisor = PostRevisor.new(post)
      revisor.revise!(post.user, raw: 'hello world123456789')
    end

    it "should allow posting more than 2 replies" do
      3.times do
        post = Fabricate(:post, user: user, topic: topic)
        Fabricate(:post, user: other_user, topic: topic)
        validator.force_edit_last_validator(post)
        expect(post.errors.count).to eq(0)
      end
    end
  end

  shared_examples "almost no validations" do
    it "skips most validations" do
      validator.expects(:stripped_length).never
      validator.expects(:raw_quality).never
      validator.expects(:max_posts_validator).never
      validator.expects(:max_mention_validator).never
      validator.expects(:max_images_validator).never
      validator.expects(:max_attachments_validator).never
      validator.expects(:newuser_links_validator).never
      validator.expects(:unique_post_validator).never
      validator.expects(:force_edit_last_validator).never
      validator.validate(post)
    end
  end

  context "admin editing a static page" do
    before do
      post.acting_user = build(:admin)
      SiteSetting.tos_topic_id = post.topic_id
    end

    include_examples "almost no validations"
  end

  context "staged user" do
    before { post.acting_user = build(:user, staged: true) }
    include_examples "almost no validations"
  end

end
