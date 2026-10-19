# frozen_string_literal: true

describe "Unified new topic list" do
  fab!(:user)
  fab!(:group) { Fabricate(:group, users: [user]) }
  fab!(:category)
  fab!(:tag)

  fab!(:new_reply) { Fabricate(:new_reply_topic, current_user: user) }
  fab!(:new_topic) { Fabricate(:post).topic }
  fab!(:old_topic) { Fabricate(:read_topic, current_user: user) }

  fab!(:new_reply_in_category) do
    Fabricate(:new_reply_topic, category: category, current_user: user)
  end

  fab!(:new_topic_in_category) do
    Fabricate(:post, topic: Fabricate(:topic, category: category)).topic
  end

  fab!(:old_topic_in_category) { Fabricate(:read_topic, category: category, current_user: user) }
  fab!(:new_reply_with_tag) { Fabricate(:new_reply_topic, tags: [tag], current_user: user) }

  fab!(:new_topic_with_tag) { Fabricate(:post, topic: Fabricate(:topic, tags: [tag])).topic }
  fab!(:old_topic_with_tag) { Fabricate(:read_topic, tags: [tag], current_user: user) }

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:tabs_toggle) { PageObjects::Components::NewTopicListToggle.new }
  let(:empty_state) { PageObjects::Components::EmptyState.new }

  before { sign_in(user) }

  shared_examples "new list new topics and replies toggle" do
    context "when unified new is enabled" do
      before { SiteSetting.enable_unified_new = true }

      it "lets the user switch between all new topics, topics, and replies" do
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(topic_list).to have_topics(count: 6)
        [
          new_reply,
          new_topic,
          new_reply_in_category,
          new_topic_in_category,
          new_reply_with_tag,
          new_topic_with_tag,
        ].each { |topic| expect(topic_list).to have_topic(topic) }

        expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(3)
        expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(3)

        expect(tabs_toggle.all_tab).to be_active
        expect(tabs_toggle.replies_tab).to be_inactive
        expect(tabs_toggle.topics_tab).to be_inactive

        tabs_toggle.topics_tab.click

        expect(topic_list).to have_topics(count: 3)
        [new_topic, new_topic_in_category, new_topic_with_tag].each do |topic|
          expect(topic_list).to have_topic(topic)
        end

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_inactive
        expect(tabs_toggle.topics_tab).to be_active

        expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(3)
        expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(3)

        expect(browser_page).to have_url("/new?subset=topics")

        tabs_toggle.all_tab.click

        expect(tabs_toggle.all_tab).to be_active
        expect(topic_list).to have_topics(count: 6)

        tabs_toggle.replies_tab.click

        expect(topic_list).to have_topics(count: 3)
        [new_reply, new_reply_in_category, new_reply_with_tag].each do |topic|
          expect(topic_list).to have_topic(topic)
        end

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_active
        expect(tabs_toggle.topics_tab).to be_inactive

        expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(3)
        expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(3)

        expect(browser_page).to have_url("/new?subset=replies")
      end

      it "respects the subset query param and activates the appropriate tab" do
        browser_page
          .goto("/new?subset=topics")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_inactive
        expect(tabs_toggle.topics_tab).to be_active

        browser_page
          .goto("/new?subset=replies")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_active
        expect(tabs_toggle.topics_tab).to be_inactive
      end

      it "strips out the subset query params when switching back to the All tab from any of the other tabs" do
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        tabs_toggle.replies_tab.click

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_active

        expect(browser_page).to have_url("/new?subset=replies")

        tabs_toggle.all_tab.click

        expect(tabs_toggle.all_tab).to be_active
        expect(tabs_toggle.replies_tab).to be_inactive
        expect(browser_page).to have_url("/new")
      end

      it "live-updates the counts shown on the tabs" do
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(3)
        expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(3)

        TopicUser.update_last_read(user, new_reply_in_category.id, 2, 1, 1)

        expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(2)
        expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(3)

        TopicUser.update_last_read(user, new_topic.id, 1, 1, 1)

        expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(2)
        expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(2)
      end

      context "when the /new topic list is scoped to a category" do
        it "lets the user switch between new topics and replies in the category" do
          browser_page
            .goto("/c/#{category.slug}/#{category.id}/l/new")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(topic_list).to have_topics(count: 2)
          expect(topic_list).to have_topic(new_reply_in_category)
          expect(topic_list).to have_topic(new_topic_in_category)

          expect(tabs_toggle.all_tab).to be_active
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_inactive

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(1)

          tabs_toggle.topics_tab.click

          expect(topic_list).to have_topics(count: 1)
          expect(topic_list).to have_topic(new_topic_in_category)

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_active

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(1)

          expect(browser_page).to have_url("/c/#{category.slug}/#{category.id}/l/new?subset=topics")

          tabs_toggle.all_tab.click

          expect(tabs_toggle.all_tab).to be_active
          expect(topic_list).to have_topics(count: 2)

          tabs_toggle.replies_tab.click

          expect(topic_list).to have_topics(count: 1)
          expect(topic_list).to have_topic(new_reply_in_category)

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_active
          expect(tabs_toggle.topics_tab).to be_inactive

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(1)

          expect(browser_page).to have_url(
            "/c/#{category.slug}/#{category.id}/l/new?subset=replies",
          )
        end

        it "respects the subset query param and activates the appropriate tab" do
          browser_page
            .goto("/c/#{category.slug}/#{category.id}/l/new?subset=topics")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_active

          browser_page
            .goto("/c/#{category.slug}/#{category.id}/l/new?subset=replies")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_active
          expect(tabs_toggle.topics_tab).to be_inactive
        end

        it "live-updates the counts shown on the tabs" do
          Fabricate(:post, topic: Fabricate(:topic, category: category))

          browser_page
            .goto("/c/#{category.slug}/#{category.id}/l/new")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(2)

          TopicUser.update_last_read(user, new_topic_in_category.id, 1, 1, 1)

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(1)
        end
      end

      context "when the /new topic list is scoped to a tag" do
        it "lets the user switch between new topics and replies with the tag" do
          browser_page
            .goto("/tag/#{tag.slug}/#{tag.id}/l/new")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(topic_list).to have_topics(count: 2)
          [new_reply_with_tag, new_topic_with_tag].each do |topic|
            expect(topic_list).to have_topic(topic)
          end

          expect(tabs_toggle.all_tab).to be_active
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_inactive

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(1)

          tabs_toggle.topics_tab.click

          expect(topic_list).to have_topics(count: 1)
          expect(topic_list).to have_topic(new_topic_with_tag)

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_active

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(1)

          expect(browser_page).to have_url("/tag/#{tag.slug}/#{tag.id}/l/new?subset=topics")

          tabs_toggle.all_tab.click

          expect(tabs_toggle.all_tab).to be_active
          expect(topic_list).to have_topics(count: 2)

          tabs_toggle.replies_tab.click

          expect(topic_list).to have_topics(count: 1)
          expect(topic_list).to have_topic(new_reply_with_tag)

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_active
          expect(tabs_toggle.topics_tab).to be_inactive

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(1)

          expect(browser_page).to have_url("/tag/#{tag.slug}/#{tag.id}/l/new?subset=replies")
        end

        it "respects the subset query param and activates the appropriate tab" do
          browser_page
            .goto("/tag/#{tag.slug}/#{tag.id}/l/new?subset=topics")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_active

          browser_page
            .goto("/tag/#{tag.slug}/#{tag.id}/l/new?subset=replies")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_active
          expect(tabs_toggle.topics_tab).to be_inactive
        end

        it "live-updates the counts shown on the tabs" do
          Fabricate(:post, topic: Fabricate(:topic, tags: [tag]))

          browser_page
            .goto("/tag/#{tag.slug}/#{tag.id}/l/new")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(2)

          TopicUser.update_last_read(user, new_topic_with_tag.id, 1, 1, 1)

          expect(tabs_toggle.replies_tab).to RSpecPredicates.have_count(1)
          expect(tabs_toggle.topics_tab).to RSpecPredicates.have_count(1)
        end
      end
    end

    context "when unified new is not enabled" do
      before { SiteSetting.enable_unified_new = false }

      it "doesn't show the tabs toggle" do
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(tabs_toggle).to be_not_rendered
      end
    end
  end

  context "when on mobile", mobile: true do
    include_examples "new list new topics and replies toggle"

    context "when there are no new topics" do
      before do
        SiteSetting.enable_unified_new = true

        [new_topic, new_topic_in_category, new_topic_with_tag].each do |topic|
          TopicUser.update_last_read(user, topic.id, 1, 1, 1)
        end
      end

      it "shows All, Topics, and Replies tabs" do
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(tabs_toggle).to be_rendered
        expect(tabs_toggle.all_tab).to RSpecPredicates.be_visible
        expect(tabs_toggle.replies_tab).to RSpecPredicates.be_visible
        expect(tabs_toggle.topics_tab).to RSpecPredicates.be_visible
      end

      it "shows a CTA to show replies when on the new topics tab" do
        browser_page
          .goto("/new?subset=topics")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(empty_state).to have_cta_text(I18n.t("js.topic.browse_new_replies"))
        empty_state.click_cta

        expect(tabs_toggle.replies_tab).to be_active
        expect(browser_page).to have_url("/new?subset=replies")
      end
    end

    context "when there are no new replies" do
      before do
        SiteSetting.enable_unified_new = true

        [new_reply, new_reply_in_category, new_reply_with_tag].each do |topic|
          TopicUser.update_last_read(user, topic.id, 2, 1, 1)
        end
      end

      it "shows All, Topics, and Replies tabs" do
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(tabs_toggle).to be_rendered
        expect(tabs_toggle.all_tab).to RSpecPredicates.be_visible
        expect(tabs_toggle.replies_tab).to RSpecPredicates.be_visible
        expect(tabs_toggle.topics_tab).to RSpecPredicates.be_visible
      end

      it "shows a CTA to show topics when on the new replies tab" do
        browser_page
          .goto("/new?subset=replies")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(empty_state).to have_cta_text(I18n.t("js.topic.browse_new_topics"))
        empty_state.click_cta

        expect(tabs_toggle.topics_tab).to be_active
        expect(browser_page).to have_url("/new?subset=topics")
      end
    end
  end

  context "when on desktop" do
    include_examples "new list new topics and replies toggle"

    context "when there's only new topics" do
      before do
        SiteSetting.enable_unified_new = true

        [new_reply, new_reply_in_category, new_reply_with_tag].each do |topic|
          TopicUser.update_last_read(user, topic.id, 2, 1, 1)
        end
      end

      it "shows All, Topics, and Replies tabs" do
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(tabs_toggle).to be_rendered
        expect(tabs_toggle.all_tab).to RSpecPredicates.be_visible
        expect(tabs_toggle.replies_tab).to RSpecPredicates.be_visible
        expect(tabs_toggle.topics_tab).to RSpecPredicates.be_visible
      end

      it "shows a CTA to show topics when on the new replies tab" do
        browser_page
          .goto("/new?subset=replies")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(empty_state).to have_cta_text(I18n.t("js.topic.browse_new_topics"))
        empty_state.click_cta

        expect(tabs_toggle.topics_tab).to be_active
        expect(browser_page).to have_url("/new?subset=topics")
      end
    end

    context "when there's only new replies" do
      before do
        SiteSetting.enable_unified_new = true

        [new_topic, new_topic_in_category, new_topic_with_tag].each do |topic|
          TopicUser.update_last_read(user, topic.id, 1, 1, 1)
        end
      end

      it "shows All, Topics, and Replies tabs" do
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(tabs_toggle).to be_rendered
        expect(tabs_toggle.all_tab).to RSpecPredicates.be_visible
        expect(tabs_toggle.replies_tab).to RSpecPredicates.be_visible
        expect(tabs_toggle.topics_tab).to RSpecPredicates.be_visible
      end

      it "shows a CTA to show replies when on the new topics tab" do
        browser_page
          .goto("/new?subset=topics")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(empty_state).to have_cta_text(I18n.t("js.topic.browse_new_replies"))
        empty_state.click_cta

        expect(tabs_toggle.replies_tab).to be_active
        expect(browser_page).to have_url("/new?subset=replies")
      end
    end
  end
end
