require 'spec_helper'
require_dependency 'validators/post_validator'

describe Validators::PostValidator do
  let :post do
    build(:post)
  end

  let :validator do
    Validators::PostValidator.new({})
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
        post.errors.count.should == 0
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
        post.errors.count.should == 0
      end
    end
  end

end
