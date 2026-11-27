# frozen_string_literal: true

describe "glimmer topic list" do
  fab!(:user)

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(user) }

  describe "/latest" do
    it "shows the list" do
      Fabricate.times(5, :topic)
      visit("/latest")

      expect(topic_list).to have_topics(count: 5)
    end
  end

  describe "/new" do
    it "shows the list and the toggle buttons" do
      SiteSetting.enable_unified_new = true
      Fabricate(:topic)
      Fabricate(:new_reply_topic, current_user: user)

      visit("/new")

      expect(topic_list).to have_topics(count: 2)
      expect(page).to have_css(".topics-replies-toggle.--all")
      expect(page).to have_css(".topics-replies-toggle.--topics")
      expect(page).to have_css(".topics-replies-toggle.--replies")
    end
  end

  describe "desktop row navigation" do
    fab!(:category)
    fab!(:listed_topic) { Fabricate(:post, topic: Fabricate(:topic, category:)).topic }

    def row
      find(".topic-list-item[data-topic-id='#{listed_topic.id}']")
    end

    it "keeps non-link cells inactive by default" do
      visit "/latest"
      row.find("td.views").click
      expect(page).to have_current_path("/latest")
    end

    context "when desktop rows are clickable" do
      before { SiteSetting.enable_clickable_desktop_topic_rows = true }

      it "opens the topic from a non-link cell" do
        visit "/latest"
        row.find("td.views").click
        expect(topic_page).to have_topic_title(listed_topic.title)
      end

      it "preserves category link navigation" do
        visit "/latest"
        row.find("a[href='#{category.url}']").click
        expect(page).to have_current_path(category.url)
      end

      it "does not navigate while selecting row text" do
        visit "/latest"

        page.execute_script(<<~JS, row)
            const selection = window.getSelection();
            selection.selectAllChildren(arguments[0].querySelector(".raw-topic-link"));
            arguments[0].querySelector("td.views").click();
          JS

        expect(page).to have_current_path("/latest")
      end

      it "opens a new tab from Control-click and middle-click" do
        visit "/latest"

        { click: { button: 0, ctrlKey: true }, auxclick: { button: 1 } }.each do |event, options|
          new_tab =
            window_opened_by do
              page.execute_script(<<~JS, row.find("td.views"), event.to_s, options)
                  arguments[0].dispatchEvent(new MouseEvent(arguments[1], {
                    ...arguments[2], bubbles: true, cancelable: true
                  }));
                JS
            end

          within_window(new_tab) { expect(topic_page).to have_topic_title(listed_topic.title) }
          new_tab.close
          expect(page).to have_current_path("/latest")
        end
      end
    end
  end

  describe "categories-with-featured-topics page" do
    let(:category_list) { PageObjects::Components::CategoryList.new }

    it "shows the list" do
      SiteSetting.desktop_category_page_style = "categories_with_featured_topics"
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category)
      topic2 = Fabricate(:topic)
      CategoryFeaturedTopic.feature_topics

      visit("/categories")

      expect(category_list).to have_topic(topic)
      expect(category_list).to have_topic(topic2)
    end
  end

  describe "suggested topics" do
    it "shows the list" do
      topic1 = Fabricate(:post).topic
      topic2 = Fabricate(:post).topic
      new_reply = Fabricate(:new_reply_topic, current_user: user, count: 3)

      visit(topic1.relative_url)

      expect(topic_page).to have_suggested_topic(topic2)
      expect(page).to have_css("[data-topic-id='#{topic2.id}'] a.badge-notification.new-topic")

      expect(topic_page).to have_suggested_topic(new_reply)
      expect(
        find("[data-topic-id='#{new_reply.id}'] a.badge-notification.unread-posts").text,
      ).to eq("3")
    end
  end

  describe "topic highlighting" do
    it "highlights newly received topics" do
      Fabricate(:read_topic, current_user: user)

      visit("/latest")

      new_topic = Fabricate(:post).topic
      TopicTrackingState.publish_new(new_topic)

      topic_list.had_new_topics_alert?
      topic_list.click_new_topics_alert

      expect(topic_list).to have_highlighted_topic(new_topic)
    end

    it "highlights the previous topic after navigation" do
      topic = Fabricate(:read_topic, current_user: user)

      visit("/latest")
      topic_list.visit_topic(topic)

      expect(topic_page).to have_topic_title(topic.title)

      page.go_back

      expect(topic_list).to have_highlighted_topic(topic)
    end
  end

  describe "bulk topic selection" do
    fab!(:user, :moderator)

    it "shows the buttons and checkboxes" do
      topics = Fabricate.times(2, :topic)
      visit("/latest")

      find("button.bulk-select").click
      expect(topic_list).to have_topic_checkbox(topics.first)
      expect(page).to have_no_css("button.bulk-select-topics-dropdown-trigger")

      topic_list.click_topic_checkbox(topics.first)
      expect(page).to have_css("button.bulk-select-topics-dropdown-trigger")
    end

    context "when on mobile", mobile: true do
      it "shows the buttons and checkboxes" do
        topics = Fabricate.times(2, :topic)
        visit("/latest")

        find("button.bulk-select").click
        expect(topic_list).to have_topic_checkbox(topics.first)
        expect(page).to have_no_css("button.bulk-select-topics-dropdown-trigger")

        topic_list.click_topic_checkbox(topics.first)
        expect(page).to have_css("button.bulk-select-topics-dropdown-trigger")
      end
    end
  end

  it "unpins globally pinned topics on click" do
    topic = Fabricate(:topic, pinned_globally: true, pinned_at: Time.current)
    visit("/latest")

    expect(page).to have_css(".topic-list-item .d-icon-thumbtack:not(.unpinned)")

    find(".topic-list-item .d-icon-thumbtack").click
    expect(page).to have_css(".topic-list-item .d-icon-thumbtack.unpinned")

    wait_for { TopicUser.exists?(topic:, user:) }
    expect(TopicUser.find_by(topic:, user:).cleared_pinned_at).to_not be_nil
  end

  it "ensures visited topics have a different color" do
    not_visited_topic = Fabricate(:topic)
    Fabricate(:post, topic: not_visited_topic)

    visited_topic = Fabricate(:topic)
    Fabricate(:post, topic: visited_topic)

    visit(visited_topic.url)
    expect(page).to have_css("#post_1")

    # Visit registration in screen tracking is async. Wait for it before navigating away.
    visited_check_js = <<~JS
      (() => {
        const tracking = Discourse.lookup("service:topic-tracking-state");
        const state = tracking.findState(#{visited_topic.id});
        return state && state.last_read_post_number >= state.highest_post_number;
      })()
    JS
    wait_for(timeout: 5) { page.evaluate_script(visited_check_js) }

    # Clicking the logo is "safer" than visiting /latest so the client-side
    # app can update the visited status of the topic
    find("#site-logo").click

    visited_color = find(".topic-list .topic-list-item.visited a.title").style("color")
    not_visited_color = find(".topic-list .topic-list-item:not(.visited) a.title").style("color")

    expect(visited_color).to_not eq(not_visited_color)
  end
end
