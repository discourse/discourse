require 'spec_helper'
require_dependency 'flag_query'

describe FlagQuery do

  let(:codinghorror) { Fabricate(:coding_horror) }

  describe "flagged_posts_report" do
    it "operates correctly" do
      post = create_post
      post2 = create_post

      user2 = Fabricate(:user)
      user3 = Fabricate(:user)

      PostAction.act(codinghorror, post, PostActionType.types[:spam])
      PostAction.act(user2, post, PostActionType.types[:spam])
      mod_message = PostAction.act(user3, post, PostActionType.types[:notify_moderators], message: "this is a 10")

      PostAction.act(codinghorror, post2, PostActionType.types[:spam])
      PostAction.act(user2, post2, PostActionType.types[:spam])

      posts, users = FlagQuery.flagged_posts_report("")
      posts.count.should == 2
      first = posts.first

      users.count.should == 5
      first[:post_actions].count.should == 2

      second = posts[1]

      second[:post_actions].count.should == 3
      second[:post_actions].first[:permalink].should == mod_message.related_post.topic.url

      posts, users = FlagQuery.flagged_posts_report("",offset=1)
      posts.count.should == 1

    end
  end
end
