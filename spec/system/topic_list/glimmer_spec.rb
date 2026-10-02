# frozen_string_literal: true

describe "glimmer topic list", native_playwright: true do
  fab!(:user)

  let(:topic_list) { PageObjects::Native::TopicList.new(browser_page) }
  let(:topic_page) { PageObjects::Native::Topic.new(browser_page) }

  before { sign_in(user) }

  describe "/latest" do
    it "shows the list" do
      Fabricate.times(5, :topic)
      topic_list.visit_latest

      expect(topic_list.topics).to have_count(5)
    end
  end

  describe "/new" do
    it "shows the list and the toggle buttons" do
      SiteSetting.enable_unified_new = true
      Fabricate(:topic)
      Fabricate(:new_reply_topic, current_user: user)

      topic_list.visit_new

      expect(topic_list.topics).to have_count(2)
      expect(topic_list.all_toggle).to be_visible
      expect(topic_list.topics_toggle).to be_visible
      expect(topic_list.replies_toggle).to be_visible
    end
  end

  describe "categories-with-featured-topics page" do
    let(:category_list) { PageObjects::Native::CategoryList.new(browser_page) }

    it "shows the list" do
      SiteSetting.desktop_category_page_style = "categories_with_featured_topics"
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category)
      topic2 = Fabricate(:topic)
      CategoryFeaturedTopic.feature_topics

      category_list.visit

      expect(category_list.featured_topic(topic)).to be_visible
      expect(category_list.featured_topic(topic2)).to be_visible
    end
  end

  describe "suggested topics" do
    it "shows the list" do
      topic1 = Fabricate(:post).topic
      topic2 = Fabricate(:post).topic
      new_reply = Fabricate(:new_reply_topic, current_user: user, count: 3)

      topic_page.visit(topic1)

      expect(topic_page.suggested_topic(topic2)).to be_visible
      expect(topic_page.new_topic_badge(topic2)).to be_visible

      expect(topic_page.suggested_topic(new_reply)).to be_visible
      expect(topic_page.unread_posts_badge(new_reply)).to have_text(/^3$/, useInnerText: true)
    end
  end

  describe "topic highlighting" do
    it "highlights newly received topics" do
      Fabricate(:read_topic, current_user: user)

      topic_list.visit_latest

      new_topic = Fabricate(:post).topic
      TopicTrackingState.publish_new(new_topic)

      expect(topic_list.new_topics_alert).to be_visible
      topic_list.new_topics_alert.click

      expect(topic_list.highlighted_topic(new_topic)).to be_visible
    end

    it "highlights the previous topic after navigation" do
      topic = Fabricate(:read_topic, current_user: user)

      topic_list.visit_latest
      topic_list.open_topic(topic)

      expect(topic_page.title).to contain_text(topic.title)

      topic_list.go_back

      expect(topic_list.highlighted_topic(topic)).to be_visible
    end
  end

  describe "bulk topic selection" do
    fab!(:user, :moderator)

    it "shows the buttons and checkboxes" do
      topics = Fabricate.times(2, :topic)
      topic_list.visit_latest

      topic_list.bulk_select.click
      expect(topic_list.topic_checkbox(topics.first)).to be_visible
      expect(topic_list.bulk_actions).to have_count(0)

      topic_list.topic_checkbox(topics.first).click
      expect(topic_list.bulk_actions).to be_visible
    end

    context "when on mobile", mobile: true do
      it "shows the buttons and checkboxes" do
        topics = Fabricate.times(2, :topic)
        topic_list.visit_latest

        topic_list.bulk_select.click
        expect(topic_list.topic_checkbox(topics.first)).to be_visible
        expect(topic_list.bulk_actions).to have_count(0)

        topic_list.topic_checkbox(topics.first).click
        expect(topic_list.bulk_actions).to be_visible
      end
    end
  end

  it "unpins globally pinned topics on click" do
    topic = Fabricate(:topic, pinned_globally: true, pinned_at: Time.current)
    topic_list.visit_latest

    expect(topic_list.pinned_icon).to be_visible

    topic_list.click_pin
    expect(topic_list.unpinned_icon).to be_visible

    wait_for { TopicUser.exists?(topic:, user:) }
    expect(TopicUser.find_by(topic:, user:).cleared_pinned_at).to_not be_nil
  end

  it "ensures visited topics have a different color" do
    not_visited_topic = Fabricate(:topic)
    Fabricate(:post, topic: not_visited_topic)

    visited_topic = Fabricate(:topic)
    Fabricate(:post, topic: visited_topic)

    topic_page.visit(visited_topic)
    expect(topic_page.first_post).to be_visible

    # Visit registration in screen tracking is async. Wait for it before navigating away.
    visited_check_js = <<~JS
      (() => {
        const tracking = Discourse.lookup("service:topic-tracking-state");
        const state = tracking.findState(#{visited_topic.id});
        return state && state.last_read_post_number >= state.highest_post_number;
      })()
    JS
    wait_for(timeout: 5) { browser_page.evaluate(visited_check_js) }

    # Clicking the logo is "safer" than visiting /latest so the client-side
    # app can update the visited status of the topic
    topic_list.return_to_list

    visited_color = topic_list.visited_title.evaluate("element => getComputedStyle(element).color")
    not_visited_color =
      topic_list.unvisited_title.evaluate("element => getComputedStyle(element).color")

    expect(visited_color).to_not eq(not_visited_color)
  end
end
