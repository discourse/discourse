# frozen_string_literal: true

describe "Post stream" do
  fab!(:user)
  fab!(:admin)

  context "when posting" do
    let(:topic) { Fabricate(:topic, user: user) }
    let(:post) { Fabricate(:post, topic: topic, user: user) }

    let(:topic_page) { PageObjects::Pages::Topic.new }
    let(:composer) { PageObjects::Components::Composer.new }

    before do
      SiteSetting.post_menu_hidden_items = ""

      sign_in(admin)
    end

    it "can reply to a post and edit the reply" do
      # Visit topic and initiate reply
      topic_page.visit_topic(post.topic)
      topic_page.click_post_action_button(post, :reply)
      expect(composer).to be_opened

      # Create initial reply
      composer.type_content("This is a reply")
      composer.submit
      expect(composer).to be_closed

      # Verify initial reply
      reply = Post.last
      expect(topic_page).to have_post_number(reply.post_number)
      expect(topic_page).to have_post_content(
        post_number: reply.post_number,
        content: "This is a reply",
      )

      # Edit the reply
      expect(topic_page).to have_post_action_button(reply, :edit)
      topic_page.click_post_action_button(reply, :edit)
      expect(composer).to be_opened
      composer.type_content("This is an edited reply")
      composer.submit

      # Verify edited reply
      expect(topic_page).to have_post_action_button(reply, :edit)
      expect(topic_page).to have_post_content(
        post_number: reply.post_number,
        content: "This is an edited reply",
      )
    end
  end

  context "when hiding scrollable content" do
    let!(:topic) { Fabricate(:topic) }
    let!(:posts) { Fabricate.times(60, :post, topic: topic) }
    let(:topic_page) { PageObjects::Pages::Topic.new }

    before { sign_in(user) }

    it "hides and shows content above the post stream based on loaded posts" do
      topic_page.visit_topic(topic, post_number: 30)
      expect(
        browser_root.locator("[data-post-number='30']").filter(visible: true),
      ).not_to have_count(0)
      expect(browser_root.locator("#main-container")).to have_count(0)

      topic_page.visit_topic(topic, post_number: 1)
      expect(
        browser_root.locator("[data-post-number='1']").filter(visible: true),
      ).not_to have_count(0)
      expect(browser_root.locator("#main-container")).not_to have_count(0)
      expect(browser_root.locator("#main-container")).not_to have_css("display", "none")
      expect(browser_root.locator("#main-container")).to have_css("visibility", "visible")

      topic_page.visit_topic(topic, post_number: 30)
      expect(
        browser_root.locator("[data-post-number='30']").filter(visible: true),
      ).not_to have_count(0)
      expect(browser_root.locator("#main-container")).to have_count(0)

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_root.locator("#main-container")).not_to have_count(0)
      expect(browser_root.locator("#main-container")).not_to have_css("display", "none")
      expect(browser_root.locator("#main-container")).to have_css("visibility", "visible")
    end
  end

  context "when scrolling" do
    let!(:topic) { Fabricate(:topic) }
    let!(:posts) { Fabricate.times(20, :post, topic: topic) }

    before { sign_in(user) }

    it "cloaks posts that are far from the viewport" do
      # Visit the topic page
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}/1")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      # Ensure there are visible posts
      expect(browser_root.locator(".topic-post").filter(visible: true)).not_to have_count(0)

      post_stream = browser_root.locator(".post-stream").filter(visible: true)

      # Ensure the first post is uncloaked
      expect(
        post_stream.locator("> [data-post-number='1']").filter(visible: true),
      ).not_to have_count(0)
      expect(
        post_stream
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("> [data-post-number='1'].post-stream--cloaked")
          .filter(visible: true),
      ).to have_count(0)

      # Check that some posts are cloaked (not all posts should be fully rendered at once)
      # The posts that are far from the viewport should have the "post-stream--cloaked" class
      expect(post_stream.locator(".post-stream--cloaked").filter(visible: true)).not_to have_count(
        0,
      )

      # Get the number of the last post
      last_post_number = topic.highest_post_number

      # Scroll to the bottom of the page to load more posts
      # We use the :end key to scroll to the bottom
      browser_page.keyboard.press("End")

      # Verify that the last post is not cloaked
      expect(
        post_stream
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("> [data-post-number='#{last_post_number}'].post-stream--cloaked")
          .filter(visible: true),
      ).to have_count(0)

      # Verify that some posts at the top are now cloaked
      # we can check the first post to see if it's cloaked
      expect(
        post_stream.locator("> [data-post-number='1'].post-stream--cloaked").filter(visible: true),
      ).not_to have_count(0)
    end

    it "keeps the state of quoted posts after uncloaking them" do
      first_post = posts[0]
      second_post = posts[1]
      second_post.raw =
        "[quote=\"#{first_post.user.username}, post:1, topic:#{topic.id}\"]\nHello\n[/quote]\n#{first_post.raw}"

      # Rebake the post to process the quote markup
      second_post.rebake!

      # Visit the topic page
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}/1")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      post2_selector = "[data-post-number='2']"

      # Find the post-stream container
      post_stream = browser_root.locator(".post-stream").filter(visible: true)

      # Verify the second post is initially visible (uncloaked)
      expect(post_stream.locator(post2_selector).filter(visible: true)).not_to have_count(0)
      expect(
        post_stream
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("#{post2_selector}.post-stream--cloaked")
          .filter(visible: true),
      ).to have_count(0)

      # Verify the quote starts collapsed
      expect(
        post_stream.locator("#{post2_selector} aside.quote[data-expanded='false']").filter(
          visible: true,
        ),
      ).not_to have_count(0)

      # Find the blockquote and verify the initial state
      blockquote =
        post_stream.locator("#{post2_selector} aside.quote blockquote").filter(visible: true)
      expect(blockquote).to contain_text(browser_text_pattern("Hello"), useInnerText: true)
      expect(
        blockquote.tap do |parent|
          parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
        end,
      ).not_to contain_text(browser_text_pattern(first_post.raw), useInnerText: true)

      # Expand the quote by clicking the toggle button
      post_stream
        .locator("#{post2_selector} aside.quote[data-expanded='false'] button.quote-toggle")
        .filter(visible: true)
        .click
      expect(
        post_stream.locator("#{post2_selector} aside.quote[data-expanded='true']").filter(
          visible: true,
        ),
      ).not_to have_count(0)

      # Verify the expanded quote shows full content
      blockquote =
        post_stream.locator("#{post2_selector} aside.quote blockquote").filter(visible: true)
      expect(blockquote).to contain_text(browser_text_pattern(first_post.raw), useInnerText: true)

      # Scroll to bottom to trigger post cloaking
      browser_page.keyboard.press("End")

      # Verify that the second post gets cloaked and the quote is removed
      expect(
        post_stream.locator("#{post2_selector}.post-stream--cloaked").filter(visible: true),
      ).not_to have_count(0)
      expect(
        post_stream
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("#{post2_selector} aside.quote")
          .filter(visible: true),
      ).to have_count(0)

      # Scroll back to top
      browser_page.keyboard.press("Home")

      # Verify that the second post becomes visible again
      expect(post_stream.locator(post2_selector).filter(visible: true)).not_to have_count(0)
      expect(
        post_stream
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("#{post2_selector}.post-stream--cloaked")
          .filter(visible: true),
      ).to have_count(0)

      # Verify that the quote maintains an expanded state after uncloaking
      expect(
        post_stream.locator("#{post2_selector} aside.quote[data-expanded='true']").filter(
          visible: true,
        ),
      ).not_to have_count(0)
      blockquote =
        post_stream.locator("#{post2_selector} aside.quote blockquote").filter(visible: true)
      expect(blockquote).to contain_text(browser_text_pattern(first_post.raw), useInnerText: true)
    end
  end
end
