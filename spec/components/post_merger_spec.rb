require 'rails_helper'
require 'post_merger'

describe PostMerger do

  before do
    ActiveRecord::Base.observers.enable :all
  end

  let(:moderator) { Fabricate(:moderator) }
  let(:admin) { Fabricate(:admin) }
  let(:post) { create_post }

  describe "merge posts" do

    it "merges 3 posts" do
      Fabricate(:admin)
      topic = post.topic
      reply1 = create_post(topic: topic, raw: 'The first reply')
      reply2 = create_post(topic: topic, raw: %q{The second reply
Second line}
)
      reply3 = create_post(topic: topic, raw: 'The third reply')

      expected_output = %q{The first reply

The second reply
Second line

The third reply}


      replies = []
      replies.push(reply1)
      replies.push(reply2)
      replies.push(reply3)

      postContent = []
      replies.each {|p| postContent.push(p.raw) }

      PostMerger.new(admin, replies).merge

      expect(reply1.deleted_at).not_to eq(nil)
      expect(reply2.deleted_at).not_to eq(nil)
      expect(reply3.deleted_at).to eq(nil)
      expect(reply3.edit_reason).to eq("Merged 3 posts by " + admin.name)
      expect(reply3.raw).to eq(expected_output)
    end

    it "does not merge 1 topic and 2 posts" do
      Fabricate(:admin)
      topic = post.topic
      reply1 = create_post(topic: topic)
      reply2 = create_post(topic: topic)

      replies = []
      replies.push(topic)
      replies.push(reply1)
      replies.push(reply2)

      reply2Raw = reply2.raw

      expect{PostMerger.new(admin, replies).merge}.to raise_error(NoMethodError)

      expect(topic.deleted_at).to eq(nil)
      expect(reply1.deleted_at).to eq(nil)
      expect(reply2.deleted_at).to eq(nil)
      expect(reply2.raw).to eq(reply2Raw)
    end

  end
end

