require 'rails_helper'
require_dependency 'flag_query'

describe FlagQuery do

  let(:codinghorror) { Fabricate(:coding_horror) }

  describe "flagged_topics" do
    it "respects `min_flags_staff_visibility`" do
      admin = Fabricate(:admin)
      moderator = Fabricate(:moderator)

      post = create_post

      PostAction.act(moderator, post, PostActionType.types[:spam])

      SiteSetting.min_flags_staff_visibility = 1

      result = FlagQuery.flagged_topics
      expect(result[:flagged_topics]).to be_present
      ft = result[:flagged_topics].first
      expect(ft.topic).to eq(post.topic)
      expect(ft.flag_counts).to eq(PostActionType.types[:spam] => 1)

      SiteSetting.min_flags_staff_visibility = 2

      result = FlagQuery.flagged_topics
      expect(result[:flagged_topics]).to be_blank

      PostAction.act(admin, post, PostActionType.types[:inappropriate])
      result = FlagQuery.flagged_topics
      expect(result[:flagged_topics]).to be_present
      ft = result[:flagged_topics].first
      expect(ft.topic).to eq(post.topic)
      expect(ft.flag_counts).to eq(
        PostActionType.types[:spam] => 1,
        PostActionType.types[:inappropriate] => 1
      )
    end

  end

  describe "flagged_posts_report" do
    it "does not return flags on system posts" do
      admin = Fabricate(:admin)
      post = create_post(user: Discourse.system_user)
      PostAction.act(codinghorror, post, PostActionType.types[:spam])
      posts, topics, users = FlagQuery.flagged_posts_report(admin)

      expect(posts).to be_blank
      expect(topics).to be_blank
      expect(users).to be_blank
    end

    it "operates correctly" do
      admin = Fabricate(:admin)
      moderator = Fabricate(:moderator)

      post = create_post
      post2 = create_post

      user2 = Fabricate(:user)
      user3 = Fabricate(:user)

      PostAction.act(codinghorror, post, PostActionType.types[:spam])
      PostAction.act(user2, post, PostActionType.types[:spam])
      mod_message = PostAction.act(user3, post, PostActionType.types[:notify_moderators], message: "this is a :one::zero:")

      PostAction.act(codinghorror, post2, PostActionType.types[:spam])
      PostAction.act(user2, post2, PostActionType.types[:spam])

      posts, topics, users = FlagQuery.flagged_posts_report(admin)

      expect(posts.count).to eq(2)
      first = posts.first

      expect(users.count).to eq(5)
      expect(first[:post_actions].count).to eq(2)

      expect(topics.count).to eq(2)

      second = posts[1]

      expect(second[:post_actions].count).to eq(3)
      expect(second[:post_actions].first[:permalink]).to eq(mod_message.related_post.topic.relative_url)
      expect(second[:post_actions].first[:conversation][:response][:excerpt]).to match("<img src=")

      posts, users = FlagQuery.flagged_posts_report(admin, offset: 1)
      expect(posts.count).to eq(1)

      # Try by topic
      posts = FlagQuery.flagged_posts_report(admin, topic_id: post.topic_id)
      expect(posts).to be_present
      posts = FlagQuery.flagged_posts_report(admin, topic_id: -1)
      expect(posts[0]).to be_blank

      # Try by user
      posts = FlagQuery.flagged_posts_report(admin, user_id: post.user_id)
      expect(posts).to be_present
      posts = FlagQuery.flagged_posts_report(admin, user_id: -1000)
      expect(posts[0]).to be_blank

      # chuck post in category a mod can not see and make sure its missing
      category = Fabricate(:category)
      category.set_permissions(admins: :full)
      category.save
      post2.topic.category_id = category.id
      post2.topic.save

      posts, users = FlagQuery.flagged_posts_report(moderator)

      expect(posts.count).to eq(1)
    end

    it "respects `min_flags_staff_visibility`" do
      admin = Fabricate(:admin)
      flagger = Fabricate(:user)

      post = create_post

      PostAction.act(flagger, post, PostActionType.types[:spam])

      SiteSetting.min_flags_staff_visibility = 2
      posts, topics, users = FlagQuery.flagged_posts_report(admin)
      expect(posts).to be_blank
      expect(topics).to be_blank
      expect(users).to be_blank

      PostAction.act(admin, post, PostActionType.types[:inappropriate])
      posts, topics, users = FlagQuery.flagged_posts_report(admin)
      expect(posts).to be_present
      expect(topics).to be_present
      expect(users).to be_present
    end

    it "respects `min_flags_staff_visibility` for tl3 hidden spam" do
      admin = Fabricate(:admin)
      tl3 = Fabricate(:user, trust_level: 3)
      post = create_post

      post.user.update_column(:trust_level, 0)
      PostAction.act(tl3, post, PostActionType.types[:spam])

      SiteSetting.min_flags_staff_visibility = 2
      posts, topics, users = FlagQuery.flagged_posts_report(admin)
      expect(posts).to be_present
      expect(topics).to be_present
      expect(users).to be_present
    end

    it "respects `min_flags_staff_visibility` for tl4 hidden posts" do
      admin = Fabricate(:admin)
      tl4 = Fabricate(:user, trust_level: 4)
      post = create_post
      PostAction.act(tl4, post, PostActionType.types[:spam])

      SiteSetting.min_flags_staff_visibility = 2
      posts, topics, users = FlagQuery.flagged_posts_report(admin)
      expect(posts).to be_present
      expect(topics).to be_present
      expect(users).to be_present
    end

  end
end
