require 'rails_helper'
require_dependency 'validators/post_validator'

describe Validators::PostValidator do
  let(:post) { build(:post) }
  let(:validator) { Validators::PostValidator.new({}) }

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

  context "invalid post" do
    it "should be invalid" do
      validator.validate(post)
      expect(post.errors.count).to be > 0
    end
  end

  describe "unique_post_validator" do
    before do
      SiteSetting.stubs(:unique_posts_mins).returns(5)
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

  shared_examples "almost no validations" do
    it "skips most validations" do
      validator.expects(:stripped_length).never
      validator.expects(:raw_quality).never
      validator.expects(:max_posts_validator).never
      validator.expects(:max_mention_validator).never
      validator.expects(:max_images_validator).never
      validator.expects(:max_attachments_validator).never
      validator.expects(:max_links_validator).never
      validator.expects(:unique_post_validator).never
      validator.validate(post)
    end
  end

  context "admin editing a static page" do
    before do
      post.acting_user = build(:admin)
      SiteSetting.stubs(:tos_topic_id).returns(post.topic_id)
    end

    include_examples "almost no validations"
  end

  context "staged user" do
    before { post.acting_user = build(:user, staged: true) }
    include_examples "almost no validations"
  end

end
