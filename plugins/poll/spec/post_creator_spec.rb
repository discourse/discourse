require 'spec_helper'
require 'post_creator'

describe PostCreator do
  let(:user) { Fabricate(:user) }

  context "poll topic" do
    it "cannot be created without a list of options" do
      post = PostCreator.create(user, {title: "Poll: This is a poll", raw: "body does not contain a list"})
      post.errors[:raw].should be_present
    end

    it "cannot have options changed after 5 minutes" do
      post = PostCreator.create(user, {title: "Poll: This is a poll", raw: "[poll]\n* option 1\n* option 2\n* option 3\n* option 4\n[/poll]"})
      post.raw = "[poll]\n* option 1\n* option 2\n* option 3\n[/poll]"
      post.valid?.should be_true
      post.save
      Timecop.freeze(Time.now + 6.minutes) do
        post.raw = "[poll]\n* option 1\n* option 2\n* option 3\n* option 4\n[/poll]"
        post.valid?.should be_false
        post.errors[:raw].should be_present
      end
    end
  end
end
