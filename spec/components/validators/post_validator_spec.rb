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

end
