require 'rails_helper'
require_dependency 'flag_query'

describe FlagQuery do

  let(:codinghorror) { Fabricate(:coding_horror) }

  describe "flagged_posts_report" do
    it "operates correctly" do
      admin = Fabricate(:admin)
      moderator = Fabricate(:moderator)

      post = create_post
      post2 = create_post

      user2 = Fabricate(:user)
      user3 = Fabricate(:user)

      PostAction.act(codinghorror, post, PostActionType.types[:spam])
      PostAction.act(user2, post, PostActionType.types[:spam])
      mod_message = PostAction.act(user3, post, PostActionType.types[:notify_moderators], message: "this is a 10")

      PostAction.act(codinghorror, post2, PostActionType.types[:spam])
      PostAction.act(user2, post2, PostActionType.types[:spam])

      posts, topics, users = FlagQuery.flagged_posts_report(admin, "")
      expect(posts.count).to eq(2)
      first = posts.first

      expect(users.count).to eq(5)
      expect(first[:post_actions].count).to eq(2)

      expect(topics.count).to eq(2)

      second = posts[1]

      expect(second[:post_actions].count).to eq(3)
      expect(second[:post_actions].first[:permalink]).to eq(mod_message.related_post.topic.relative_url)

      posts, users = FlagQuery.flagged_posts_report(admin, "", 1)
      expect(posts.count).to eq(1)

      # chuck post in category a mod can not see and make sure its missing
      category = Fabricate(:category)
      category.set_permissions(:admins => :full)
      category.save
      post2.topic.category_id = category.id
      post2.topic.save

      posts, users = FlagQuery.flagged_posts_report(moderator, "")

      expect(posts.count).to eq(1)
    end
  end
end
