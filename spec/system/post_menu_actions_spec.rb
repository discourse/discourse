# frozen_string_literal: true

describe "Post menu", :soft_reset do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic, reload: true)
  fab!(:post, reload: true) { Fabricate(:post, topic: topic, reads: 5, like_count: 6) }
  fab!(:post2, reload: true) { Fabricate(:post, user: user, topic: topic, like_count: 0) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:flag_modal) { PageObjects::Modals::Flag.new }
  let(:login_page) { PageObjects::Pages::Login.new }
  let(:modal) { PageObjects::Modals::Base.new }

  before do
    SiteSetting.post_menu = "like|copyLink|share|flag|edit|bookmark|delete|admin|reply"
    SiteSetting.post_menu_hidden_items = "flag|bookmark|edit|delete|admin"
  end

  describe "flag" do
    before { SiteSetting.post_menu_hidden_items = "" }

    it "displays the flag button only when the user can flag the post" do
      # do not display the edit button when unlogged
      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_no_post_action_button(post, :flag)
      expect(topic_page).to have_no_post_action_button(post2, :flag)

      # display the flag button only for the post that `user` can flag
      sign_in(user)

      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_post_action_button(post, :flag)
      expect(topic_page).to have_post_action_button(post2, :flag)

      # display the flag button for the all the posts because an admin is logged
      sign_in(admin)

      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_post_action_button(post, :flag)
      expect(topic_page).to have_post_action_button(post2, :flag)
    end

    it "works as expected" do
      sign_in(user)

      topic_page.visit_topic(post2.topic)

      expect(flag_modal).to be_closed
      topic_page.click_post_action_button(post2, :flag)
      expect(flag_modal).to be_open
    end
  end

  describe "like" do
    it "toggles liking a post" do
      unliked_post = Fabricate(:post, topic: topic, like_count: 0)

      sign_in(user)

      topic_page.visit_topic(unliked_post.topic)

      expect(topic_page).to have_post_action_button(unliked_post, :like)
      like_button = topic_page.find_post_action_button(unliked_post, :like)
      expect(like_button[:class].split("\s")).to include("like")

      expect(topic_page).to have_no_post_action_button(unliked_post, :like_count)

      # toggle the like on
      topic_page.click_post_action_button(unliked_post, :like)

      # we need this because the find_post_action_button will target the like button on or off
      try_until_success(reason: "Relies on Ember debounce") do
        like_button = topic_page.find_post_action_button(unliked_post, :like)
        expect(like_button[:class].split("\s")).to include("has-like")
      end

      like_count_button = topic_page.find_post_action_button(unliked_post, :like_count)
      expect(like_count_button).to have_content(1)

      # toggle the like off
      topic_page.click_post_action_button(unliked_post, :like)

      # we need this because the find_post_action_button will target the like button on or off
      try_until_success(reason: "Relies on Ember debounce") do
        like_button = topic_page.find_post_action_button(unliked_post, :like)
        expect(like_button[:class].split("\s")).to include("like")
      end

      expect(topic_page).to have_no_post_action_button(unliked_post, :like_count)
    end

    it "displays the login dialog when the user is anonymous" do
      topic_page.visit_topic(post2.topic)

      expect(topic_page).to have_post_action_button(post2, :like)
      like_button = topic_page.find_post_action_button(post2, :like)
      expect(like_button[:title]).to eq(I18n.t("js.post.controls.like"))

      expect(topic_page).to have_no_post_action_button(post2, :like_count)

      # clicking on the like button should display the login modal
      topic_page.click_post_action_button(post2, :like)

      expect(login_page).to be_open
    end

    it "renders the like count as expected" do
      topic_page.visit_topic(post.topic)

      # renders the like count when the it's not zero
      like_count_button = topic_page.find_post_action_button(post, :like_count)
      expect(like_count_button).to have_content(post.like_count)

      # does not render the like count when it's zero
      expect(topic_page).to have_no_post_action_button(post2, :like_count)
    end

    it "shows the users who liked when clicking on the like count" do
      SiteSetting.enable_new_post_reactions_menu = true
      PostActionCreator.like(user, post)
      PostActionCreator.like(admin, post)

      topic_page.visit_topic(post.topic)

      # show users who liked on
      topic_page.click_post_action_button(post, :like_count)
      expect(topic_page).to have_who_liked_on_post(post, count: 2)
    end

    it "does not allow silenced users to like posts" do
      user.update!(silenced_till: 1.year.from_now)

      sign_in(user)

      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_no_post_action_button(post, :like)
    end
  end

  describe "read" do
    fab!(:group) { Fabricate(:group, publish_read_state: true) }
    fab!(:group_user) { Fabricate(:group_user, group: group, user: user) }
    fab!(:group_user2) { Fabricate(:group_user, group: group, user: Fabricate(:user)) }
    fab!(:pm) { Fabricate(:private_message_topic, allowed_groups: [group]) }
    fab!(:pm_post1) { Fabricate(:post, topic: pm, user: user, reads: 2, created_at: 1.day.ago) }
    fab!(:pm_post2) { Fabricate(:post, topic: pm, user: group_user2.user, reads: 0) }

    before do
      SiteSetting.post_menu = "read|like|copyLink|share|flag|edit|bookmark|delete|admin|reply"
      sign_in(user)
    end

    it "shows the read indicator when expected" do
      topic_page.visit_topic(pm)
      # it shows the read indicator on group pms where publish_read_state = true
      # when the post has reads > 0
      expect(topic_page).to have_post_action_button(pm_post1, :read)
      read_button = topic_page.find_post_action_button(pm_post1, :read)
      expect(read_button).to have_content(1)
      # don't show when the post has reads = 0
      expect(topic_page).to have_no_post_action_button(pm_post2, :read)

      # don't show on regular posts
      topic_page.visit_topic(post.topic)
      expect(topic_page).to have_no_post_action_button(post, :read)
      expect(topic_page).to have_no_post_action_button(post2, :read)
    end

    it "toggles the users who read when clicking on the read button" do
      TopicUser.update_last_read(user, pm.id, 1, 1, 1)
      TopicUser.update_last_read(admin, pm.id, 2, 1, 1)

      topic_page.visit_topic(pm)

      expect(topic_page).to have_no_who_read_on_post(pm_post1)

      # toggle users who read on
      topic_page.click_post_action_button(pm_post1, :read)
      expect(topic_page).to have_who_read_on_post(pm_post1, count: 1)

      # toggle users who read off
      topic_page.click_post_action_button(pm_post1, :read)
      expect(topic_page).to have_no_who_read_on_post(pm_post1)
    end
  end

  describe "replies" do
    fab!(:reply_to_post) do
      PostCreator.new(
        Fabricate(:user),
        raw: "Just a reply to the OP",
        topic_id: topic.id,
        reply_to_post_number: post.post_number,
      ).create
    end
    fab!(:post_with_reply, reload: true) do
      PostCreator.new(topic.user, raw: Fabricate.build(:post).raw, topic_id: topic.id).create
    end
    fab!(:reply_to_post_with_reply) do
      PostCreator.new(
        Fabricate(:user),
        raw: "A reply directly below the post",
        topic_id: topic.id,
        reply_to_post_number: post_with_reply.post_number,
      ).create
    end

    it "doesn't display the replies button when there are no replies" do
      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_no_post_action_button(post2, :replies)
    end

    it "is disabled when the post is deleted" do
      PostDestroyer.new(admin, post).destroy

      sign_in(admin)
      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_post_action_button(post, :replies)

      replies_button = topic_page.find_post_action_button(post, :replies)
      expect(replies_button[:disabled]).to eq(true)
    end

    it "displays the replies when clicked" do
      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_replies_collapsed(post)
      topic_page.click_post_action_button(post, :replies)
      expect(topic_page).to have_replies_expanded(post)

      replies_button = topic_page.find_post_action_button(post, :replies)
      expect(replies_button[:ariaExpanded]).to eq("true")
      expect(replies_button[:ariaPressed]).to eq("true")
    end

    it "is displayed correctly when the reply is directly below" do
      # it is displayed when there is only one reply directly below and the setting `suppress_reply_directly_below`
      # is disabled
      SiteSetting.suppress_reply_directly_below = false

      topic_page.visit_topic(post_with_reply.topic)
      expect(topic_page).to have_post_action_button(post_with_reply, :replies)

      # it is not displayed when there is only one reply directly below and the setting
      # `suppress_reply_directly_below` is enabled
      SiteSetting.suppress_reply_directly_below = true

      topic_page.visit_topic(post_with_reply.topic)
      expect(topic_page).to have_no_post_action_button(post_with_reply, :replies)

      # it is displayed when there is more than one reply directly below
      PostCreator.new(
        Fabricate(:user),
        raw: "A reply directly below the post",
        topic_id: topic.id,
        reply_to_post_number: post_with_reply.post_number,
      ).create

      topic_page.visit_topic(post_with_reply.topic)
      expect(topic_page).to have_post_action_button(post_with_reply, :replies)
    end
  end

  describe "reply" do
    before { SiteSetting.post_menu_hidden_items = "" }

    it "displays the reply button only when the user can reply the post" do
      # do not display the reply button when unlogged
      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_no_post_action_button(post, :reply)
      expect(topic_page).to have_no_post_action_button(post2, :reply)

      # display the reply button when the user can reply to the post
      sign_in(user)

      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_post_action_button(post, :reply)
      expect(topic_page).to have_post_action_button(post2, :reply)
    end

    it "displays the reply button less prominently when the topic is a wiki" do
      wiki_topic = Fabricate(:topic)
      wiki_post = Fabricate(:post, topic: wiki_topic, user: Fabricate(:user), wiki: true)
      non_wiki_post = Fabricate(:post, topic: wiki_topic, user: Fabricate(:user), wiki: false)

      # do not display the reply button when unlogged
      topic_page.visit_topic(wiki_post.topic)

      expect(topic_page).to have_no_post_action_button(wiki_post, :reply)
      expect(topic_page).to have_no_post_action_button(non_wiki_post, :reply)

      # display the reply button only for the post that `user` can reply
      sign_in(user)

      topic_page.visit_topic(wiki_post.topic)

      expect(topic_page).to have_post_action_button(wiki_post, :reply)
      expect(topic_page).to have_post_action_button(non_wiki_post, :reply)

      # display the reply button less prominently for the wiki post, i.e. it's not a create button
      # and the label is not displayed
      wiki_post_reply_button = topic_page.find_post_action_button(wiki_post, :reply)
      expect(wiki_post_reply_button[:class].split("\s")).not_to include("create")
      expect(wiki_post_reply_button).to have_no_content(I18n.t("js.topic.reply.title"))

      # display the reply as a create button for the non-wiki post and the label should be displayed
      non_wiki_post_reply_button = topic_page.find_post_action_button(non_wiki_post, :reply)
      expect(non_wiki_post_reply_button[:class].split("\s")).to include("create")
      expect(non_wiki_post_reply_button).to have_content(I18n.t("js.topic.reply.title"))
    end

    it "works as expected" do
      sign_in(user)

      topic_page.visit_topic(post.topic)

      expect(composer).to be_closed
      topic_page.click_post_action_button(post, :reply)

      expect(composer).to be_opened
      expect(composer).to have_content("")
    end
  end

  describe "share" do
    it "works as expected" do
      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_post_action_button(post, :share)
      topic_page.click_post_action_button(post, :share)

      expect(page).to have_css(".d-modal.share-topic-modal")
    end
  end

  describe "show more" do
    before do
      sign_in(admin)

      SiteSetting.post_menu = "like|copyLink|share|flag|edit|bookmark|delete|admin|reply"
      SiteSetting.post_menu_hidden_items = "flag|bookmark|edit|delete|admin"
    end

    it "is not displayed when `post_menu_hidden_items` is empty" do
      SiteSetting.post_menu_hidden_items = ""

      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_no_post_action_button(post, :show_more)
    end

    it "is not displayed when there is only one hidden button" do
      SiteSetting.post_menu_hidden_items = "admin"

      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_no_post_action_button(post, :show_more)
    end

    it "works as expected" do
      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_no_post_action_button(post, :flag)
      expect(topic_page).to have_no_post_action_button(post, :bookmark)
      expect(topic_page).to have_no_post_action_button(post, :edit)
      expect(topic_page).to have_no_post_action_button(post, :delete)
      expect(topic_page).to have_no_post_action_button(post, :admin)

      expect(topic_page).to have_post_action_button(post, :show_more)
      topic_page.click_post_action_button(post, :show_more)

      expect(topic_page).to have_post_action_button(post, :flag)
      expect(topic_page).to have_post_action_button(post, :bookmark)
      expect(topic_page).to have_post_action_button(post, :edit)
      expect(topic_page).to have_post_action_button(post, :delete)
      expect(topic_page).to have_post_action_button(post, :admin)
    end
  end
end
