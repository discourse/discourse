require 'rails_helper'
require_dependency 'flag_query'

describe FlagQuery do

  let(:codinghorror) { Fabricate(:coding_horror) }

  describe "flagged_topics" do
    it "respects `min_score_default_visibility`" do
      admin = Fabricate(:admin)
      moderator = Fabricate(:moderator)

      post = create_post

      SiteSetting.min_score_default_visibility = 2.0
      PostActionCreator.create(moderator, post, :spam)

      result = FlagQuery.flagged_topics
      expect(result[:flagged_topics]).to be_present
      ft = result[:flagged_topics].first
      expect(ft.topic).to eq(post.topic)
      expect(ft.flag_counts).to eq(PostActionType.types[:spam] => 1)

      SiteSetting.min_score_default_visibility = 10.0

      result = FlagQuery.flagged_topics
      expect(result[:flagged_topics]).to be_blank

      PostActionCreator.create(admin, post, :inappropriate)
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
      PostActionCreator.create(codinghorror, post, :spam)
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

      PostActionCreator.spam(codinghorror, post)
      PostActionCreator.create(user2, post, :spam)
      result = PostActionCreator.new(
        user3,
        post,
        PostActionType.types[:notify_moderators],
        message: "this is a :one::zero:"
      ).perform
      mod_message = result.post_action

      PostActionCreator.spam(codinghorror, post2)
      PostActionCreator.spam(user2, post2)

      posts, topics, users, all_actions = FlagQuery.flagged_posts_report(admin)

      expect(posts.count).to eq(2)
      first = posts.first

      expect(users.count).to eq(5)
      expect(first[:post_action_ids].count).to eq(2)

      expect(topics.count).to eq(2)

      second = posts[1]
      expect(second[:post_action_ids].count).to eq(3)

      action = all_actions.find { |a| a[:id] == second[:post_action_ids][0] }
      expect(action[:permalink]).to eq(mod_message.related_post.topic.relative_url)
      expect(action[:conversation][:response][:excerpt]).to match("<img src=")

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

      # chuck post in category a mod can not see and make sure it's not returned
      category = Fabricate(:category)
      category.set_permissions(admins: :full)
      category.save

      post2.topic.change_category_to_id(category.id)
      post2.topic.save

      posts, users = FlagQuery.flagged_posts_report(moderator)
      expect(posts.count).to eq(1)
    end

    it "respects `min_score_default_visibility`" do
      admin = Fabricate(:admin)
      flagger = Fabricate(:user)

      post = create_post
      PostActionCreator.create(flagger, post, :spam)

      SiteSetting.min_score_default_visibility = 3.0
      posts, topics, users = FlagQuery.flagged_posts_report(admin)
      expect(posts).to be_blank
      expect(topics).to be_blank
      expect(users).to be_blank

      PostActionCreator.create(admin, post, :inappropriate)
      posts, topics, users = FlagQuery.flagged_posts_report(admin)
      expect(posts).to be_present
      expect(topics).to be_present
      expect(users).to be_present
    end

  end
end
