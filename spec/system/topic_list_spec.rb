# frozen_string_literal: true

describe "Topic list" do
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }
  fab!(:admin)

  before_all do
    sidebar_url = Fabricate(:sidebar_url, name: "my topic link", value: "/t/#{topics[4].id}")

    Fabricate(
      :sidebar_section_link,
      sidebar_section:
        SidebarSection.find_by(section_type: SidebarSection.section_types[:community]),
      linkable: sidebar_url,
    )
  end

  let(:discovery) { PageObjects::Pages::Discovery.new }
  let(:topic) { PageObjects::Pages::Topic.new }

  def focussed_topic_id
    browser_page.evaluate(
      "function(arguments) { return document.activeElement.closest('.topic-list-item')?.dataset.topicId }",
      arg: [],
    )&.to_i
  end

  def focussed_post_id
    browser_page.evaluate(
      "function(arguments) { return document.activeElement.closest('.onscreen-post')?.dataset.postId }",
      arg: [],
    )&.to_i
  end

  it "refocusses last clicked topic when going back to topic list" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("body.navigation-topics").filter(visible: true)).not_to have_count(
      0,
    )
    expect(discovery.topic_list).to have_topics

    # Click a topic
    discovery.topic_list.visit_topic(topics[5])
    expect(topic).to have_topic_title(topics[5].title)

    # Going back to the topic-list should re-focus
    browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("body.navigation-topics").filter(visible: true)).not_to have_count(
      0,
    )
    expect(focussed_topic_id).to eq(topics[5].id)

    # Click topic again
    discovery.topic_list.visit_topic(topics[5])
    expect(topic).to have_topic_title(topics[5].title)

    # Visiting a topic list another way should not focus
    browser_root
      .locator(".sidebar-section-link[data-link-name='everything']")
      .filter(visible: true)
      .click
    expect(browser_root.locator("body.navigation-topics").filter(visible: true)).not_to have_count(
      0,
    )
    expect(focussed_topic_id).to eq(nil)
  end

  it "refocusses properly when navigating via the 'last activity' link" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    # Visit topic via activity column and keyboard
    discovery.topic_list.visit_topic_last_reply_via_keyboard(topics[2])
    expect(topic).to have_topic_title(topics[2].title)

    # Going back to the topic-list should re-focus
    browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("body.navigation-topics").filter(visible: true)).not_to have_count(
      0,
    )
    expect(focussed_topic_id).to eq(topics[2].id)

    # Visit topic via keyboard using posts map (OP button)
    discovery.topic_list.visit_topic_first_reply_via_keyboard(topics[4])
    expect(topic).to have_topic_title(topics[4].title)

    # Going back to the topic-list should re-focus
    browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("body.navigation-topics").filter(visible: true)).not_to have_count(
      0,
    )
    expect(focussed_topic_id).to eq(topics[4].id)
  end

  it "does not refocus topic when visiting via something other than topic list" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    # Clicking sidebar link should visit topic
    browser_root
      .locator(".sidebar-section-link[data-link-name='my topic link']")
      .filter(visible: true)
      .click
    expect(topic).to have_topic_title(topics[4].title)

    # Going back to the topic-list should not re-focus
    browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("body.navigation-topics").filter(visible: true)).not_to have_count(
      0,
    )
    expect(focussed_topic_id).to eq(nil)
  end

  it "refocusses properly when there are multiple pages of topics" do
    Fabricate.times(25, :post).map(&:topic)
    oldest_topic = Fabricate(:post).topic
    oldest_topic.update(bumped_at: 1.day.ago)

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    # Scroll to bottom for infinite load
    browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: [])
      document.querySelectorAll('.topic-list-item')[24].scrollIntoView(true);
    JS

    # Click a topic
    discovery.topic_list.visit_topic(oldest_topic)
    expect(topic).to have_topic_title(oldest_topic.title)

    # Going back to the topic-list should re-focus
    browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_root.locator("body.navigation-topics").filter(visible: true)).not_to have_count(
      0,
    )
    expect(focussed_topic_id).to eq(oldest_topic.id)
  end

  it "opens topic in new window when pressing meta+Enter" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics

    new_window =
      browser_page.expect_popup do
        discovery.topic_list.send_keys_to_topic(topics[5], %i[meta return])
      end

    using_browser_page(new_window) { expect(topic).to have_topic_title(topics[5].title) }
  end

  it "shows a topic list" do
    sign_in(admin)

    users =
      8.times.map do
        Fabricate(:user, username: Faker::Internet.username(specifier: 6..15, separators: %w[_ .]))
      end

    categories = 5.times.map { Fabricate(:category) }

    25.times do
      views = rand(80..8_000)
      topic =
        Fabricate(
          :topic,
          title:
            "Community discussion: #{Faker::Lorem.sentence(word_count: rand(6..12)).chomp(".")}",
          category: categories.sample,
        )
      Fabricate(:post, topic: topic)
      rand(2..5).times { Fabricate(:post, topic: topic, user: users.sample) }
      topic.feature_topic_users
      topic.update!(views: views, like_count: rand(views / 100..views / 4))
    end

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(discovery.topic_list).to have_topics
    screenshot_marker(label: "topic-list")

    browser_page.goto("/categories").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    screenshot_marker(label: "categories")

    browser_root.locator("#create-topic").filter(visible: true).click
    expect(browser_root.locator("#reply-control.open").filter(visible: true)).not_to have_count(0)
    screenshot_marker(label: "composer-new-topic")
  end
end
