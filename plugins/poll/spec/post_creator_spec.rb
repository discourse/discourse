require 'spec_helper'
require 'post_creator'

describe PostCreator do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  context "poll topic" do
    let(:poll_post) { PostCreator.create(user, {title: "Poll: This is a poll", raw: "[poll]\n* option 1\n* option 2\n* option 3\n* option 4\n[/poll]"}) }

    it "cannot be created without a list of options" do
      post = PostCreator.create(user, {title: "Poll: This is a poll", raw: "body does not contain a list"})
      post.errors[:raw].should be_present
    end

    it "cannot have options changed after 5 minutes" do
      poll_post.raw = "[poll]\n* option 1\n* option 2\n* option 3\n[/poll]"
      poll_post.valid?.should be_true
      poll_post.save
      Timecop.freeze(Time.now + 6.minutes) do
        poll_post.raw = "[poll]\n* option 1\n* option 2\n* option 3\n* option 4\n[/poll]"
        poll_post.valid?.should be_false
        poll_post.errors[:poll_options].should be_present
      end
    end

    it "allows staff to edit options after 5 minutes" do
      poll_post.last_editor_id = admin.id
      Timecop.freeze(Time.now + 6.minutes) do
        poll_post.raw = "[poll]\n* option 1\n* option 2\n* option 3\n* option 4.1\n[/poll]"
        poll_post.valid?.should be_true
        poll_post.raw = "[poll]\n* option 1\n* option 2\n* option 3\n[/poll]"
        poll_post.valid?.should be_false
      end
    end
  end
end
