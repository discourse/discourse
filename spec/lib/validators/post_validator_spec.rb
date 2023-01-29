# frozen_string_literal: true

RSpec.describe PostValidator do
  fab!(:topic) { Fabricate(:topic) }
  let(:post) { build(:post, topic: topic) }
  let(:validator) { PostValidator.new({}) }

  describe "#post_body_validator" do
    it "should not allow a post with an empty raw" do
      post.raw = ""
      validator.post_body_validator(post)
      expect(post.errors).to_not be_empty
    end

    context "when empty raw can bypass validation" do
      let(:validator) { PostValidator.new(skip_post_body: true) }

      it "should be allowed for empty raw based on site setting" do
        post.raw = ""
        validator.post_body_validator(post)
        expect(post.errors).to be_empty
      end
    end

    context "when post's topic is a PM between a human and a non human user" do
      fab!(:robot) { Fabricate(:bot) }
      fab!(:user) { Fabricate(:user) }

      let(:topic) do
        Fabricate(
          :private_message_topic,
          topic_allowed_users: [
            Fabricate.build(:topic_allowed_user, user: robot),
            Fabricate.build(:topic_allowed_user, user: user),
          ],
        )
      end

      it "should allow a post with an empty raw" do
        post = Fabricate.build(:post, topic: topic)
        post.raw = ""
        validator.post_body_validator(post)

        expect(post.errors).to be_empty
      end
    end
  end

  describe "stripped_length" do
    it "adds an error for short raw" do
      post.raw = "abc"
      validator.stripped_length(post)
      expect(post.errors.count).to eq(1)
    end

    it "counts emoji as a single character" do
      post.raw = ":smiling_face_with_three_hearts:" * (SiteSetting.min_post_length - 1)
      validator.stripped_length(post)
      expect(post.errors.count).to eq(1)

      post = build(:post, topic: topic)
      post.raw = ":smiling_face_with_three_hearts:" * SiteSetting.min_post_length
      validator.stripped_length(post)
      expect(post.errors.count).to eq(0)
    end

    it "counts multiple characters as a single character" do
      post.raw = "." * SiteSetting.min_post_length
      validator.stripped_length(post)
      expect(post.errors.count).to eq(1)

      post = build(:post, topic: topic)
      post.raw = "," * SiteSetting.min_post_length
      validator.stripped_length(post)
      expect(post.errors.count).to eq(1)

      post = build(:post, topic: topic)
      post.raw = "<!-- #{"very long comment" * SiteSetting.min_post_length} -->"
      validator.stripped_length(post)
      expect(post.errors.count).to eq(1)
    end

    it "adds no error for long raw" do
      post.raw = "this is a long topic body testing 123"
      validator.stripped_length(post)
      expect(post.errors.count).to eq(0)
    end

    it "ignores an html comment" do
      post.raw = "<!-- an html comment -->abc"
      validator.stripped_length(post)
      expect(post.errors.count).to eq(1)
    end

    it "ignores multiple html comments" do
      post.raw = "<!-- an html comment -->\n abc \n<!-- a comment -->"
      validator.stripped_length(post)
      expect(post.errors.count).to eq(1)
    end

    it "ignores nested html comments" do
      post.raw = "<!-- <!-- an html comment --> -->"
      validator.stripped_length(post)
      expect(post.errors.count).to eq(1)
    end
  end

  describe "too_many_posts" do
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

  describe "too_many_mentions" do
    before do
      SiteSetting.newuser_max_mentions_per_post = 2
      SiteSetting.max_mentions_per_post = 3
    end

    it "should be invalid when new user exceeds max mentions limit" do
      post.acting_user = build(:newuser)
      post.expects(:raw_mentions).returns(%w[jake finn jake_old])
      validator.max_mention_validator(post)
      expect(post.errors.count).to be > 0
    end

    it "should be invalid when leader user exceeds max mentions limit" do
      post.acting_user = build(:trust_level_4)
      post.expects(:raw_mentions).returns(%w[jake finn jake_old jake_new])
      validator.max_mention_validator(post)
      expect(post.errors.count).to be > 0
    end

    it "should be valid when new user does not exceed max mentions limit" do
      post.acting_user = build(:newuser)
      post.expects(:raw_mentions).returns(%w[jake finn])
      validator.max_mention_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be valid when new user exceeds max mentions limit in PM" do
      post.acting_user = build(:newuser)
      post.topic.expects(:private_message?).returns(true)
      post.expects(:raw_mentions).returns(%w[jake finn jake_old])
      validator.max_mention_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be valid when leader user does not exceed max mentions limit" do
      post.acting_user = build(:trust_level_4)
      post.expects(:raw_mentions).returns(%w[jake finn jake_old])
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

  describe "too_many_embedded_media" do
    before do
      SiteSetting.min_trust_to_post_embedded_media = 0
      SiteSetting.newuser_max_embedded_media = 2
    end

    it "should be invalid when new user exceeds max mentions limit" do
      post.acting_user = build(:newuser)
      post.expects(:embedded_media_count).returns(3)
      validator.max_embedded_media_validator(post)
      expect(post.errors.count).to be > 0
    end

    it "should be valid when new user does not exceed max mentions limit" do
      post.acting_user = build(:newuser)
      post.expects(:embedded_media_count).returns(2)
      validator.max_embedded_media_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be invalid when user trust level is not sufficient" do
      SiteSetting.min_trust_to_post_embedded_media = 4
      post.acting_user = build(:leader)
      post.expects(:embedded_media_count).returns(2)
      validator.max_embedded_media_validator(post)
      expect(post.errors.count).to be > 0
    end

    it "should be valid for moderator in all cases" do
      post.acting_user = build(:moderator)
      post.expects(:embedded_media_count).never
      validator.max_embedded_media_validator(post)
      expect(post.errors.count).to be(0)
    end

    it "should be valid for admin in all cases" do
      post.acting_user = build(:admin)
      post.expects(:embedded_media_count).never
      validator.max_embedded_media_validator(post)
      expect(post.errors.count).to be(0)
    end
  end

  describe "invalid post" do
    it "should be invalid" do
      validator.validate(post)
      expect(post.errors.count).to be > 0
    end
  end

  describe "unique_post_validator" do
    fab!(:user) { Fabricate(:user) }
    fab!(:post) { Fabricate(:post, raw: "Non PM topic body", user: user, topic: topic) }
    fab!(:pm_post) do
      Fabricate(:post, raw: "PM topic body", user: user, topic: Fabricate(:private_message_topic))
    end

    before do
      SiteSetting.unique_posts_mins = 5

      post.store_unique_post_key
      pm_post.store_unique_post_key

      @key = post.unique_post_key
      @pm_key = pm_post.unique_post_key
    end

    after do
      Discourse.redis.del(@key)
      Discourse.redis.del(@pm_key)
    end

    context "when post is unique" do
      let(:new_post) { Fabricate.build(:post, user: user, raw: "unique content", topic: topic) }

      it "should not add an error" do
        validator.unique_post_validator(new_post)
        expect(new_post.errors.count).to eq(0)
      end

      it "should not add an error when changing an existing post" do
        post.raw = "changing raw"

        validator.unique_post_validator(post)
        expect(post.errors.count).to eq(0)
      end
    end

    context "when post is not unique" do
      def build_post(is_pm:, raw:)
        Fabricate.build(
          :post,
          user: user,
          raw: raw,
          topic: is_pm ? Fabricate.build(:private_message_topic) : topic,
        )
      end

      it "should add an error for post dupes" do
        new_post = build_post(is_pm: false, raw: post.raw)

        validator.unique_post_validator(new_post)
        expect(new_post.errors.to_hash.keys).to contain_exactly(:raw)
      end

      it "should add an error for pm dupes" do
        new_post = build_post(is_pm: true, raw: pm_post.raw)

        validator.unique_post_validator(new_post)
        expect(new_post.errors.to_hash.keys).to contain_exactly(:raw)
      end

      it "should not add an error for cross PM / topic dupes" do
        new_post = build_post(is_pm: true, raw: post.raw)

        validator.unique_post_validator(new_post)
        expect(new_post.errors.count).to eq(0)

        new_post = build_post(is_pm: false, raw: pm_post.raw)

        validator.unique_post_validator(new_post)
        expect(new_post.errors.count).to eq(0)
      end

      it "should not add an error if post.skip_unique_check is true" do
        new_post = build_post(is_pm: false, raw: post.raw)

        new_post.skip_unique_check = true
        validator.unique_post_validator(new_post)
        expect(new_post.errors.count).to eq(0)
      end
    end
  end

  describe "force_edit_last_validator" do
    fab!(:user) { Fabricate(:user) }
    fab!(:other_user) { Fabricate(:user) }
    fab!(:topic) { Fabricate(:topic) }

    before { SiteSetting.max_consecutive_replies = 2 }

    it "should always allow original poster to post" do
      [user, user, user, other_user, user, user, user].each_with_index do |u, i|
        post = Post.new(user: u, topic: topic, raw: "post number #{i}")
        validator.force_edit_last_validator(post)
        expect(post.errors.count).to eq(0)
        post.save!
      end
    end

    it "should allow category moderators to post more than 2 consecutive replies" do
      SiteSetting.enable_category_group_moderation = true
      group = Fabricate(:group)
      GroupUser.create(group: group, user: user)
      category = Fabricate(:category, reviewable_by_group_id: group.id)
      topic.update!(category: category)

      Post.create!(user: other_user, topic: topic, raw: "post number 1", post_number: 1)
      Post.create!(user: user, topic: topic, raw: "post number 2", post_number: 2)
      Post.create!(user: user, topic: topic, raw: "post number 3", post_number: 3)

      post = Post.new(user: user, topic: topic, raw: "post number 4", post_number: 4)
      validator.force_edit_last_validator(post)
      expect(post.errors.count).to eq(0)
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
      revisor.revise!(post.user, raw: "hello world123456789")
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
      validator.expects(:max_embedded_media_validator).never
      validator.expects(:max_attachments_validator).never
      validator.expects(:newuser_links_validator).never
      validator.expects(:unique_post_validator).never
      validator.expects(:force_edit_last_validator).never
      validator.validate(post)
    end
  end

  describe "admin editing a static page" do
    before do
      post.acting_user = build(:admin)
      SiteSetting.tos_topic_id = post.topic_id
    end

    include_examples "almost no validations"
  end

  describe "staged user" do
    before { post.acting_user = build(:user, staged: true) }
    include_examples "almost no validations"
  end
end
