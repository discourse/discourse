# frozen_string_literal: true

describe "Post stream", type: :system do
  fab!(:user)
  fab!(:admin)

  %w[enabled disabled].each do |value|
    before { SiteSetting.glimmer_post_stream_mode = value }

    context "when glimmer_post_stream_mode=#{value}" do
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
    end
  end

  context "when scrolling" do
    let!(:topic) { Fabricate(:topic) }
    let!(:posts) { Fabricate.times(20, :post, topic: topic) }

    before do
      sign_in(user)
      SiteSetting.glimmer_post_stream_mode = "enabled"
    end

    it "cloaks posts that are far from the viewport" do
      # Visit the topic page
      visit "/t/#{topic.slug}/#{topic.id}/1"

      # Ensure there are visible posts
      expect(page).to have_css(".topic-post")

      post_stream = find(".post-stream")

      # Ensure the first post is uncloaked
      expect(post_stream).to have_css("> [data-post-number='1']")
      expect(post_stream).to have_no_css("> [data-post-number='1'].post-stream--cloaked")

      # Check that some posts are cloaked (not all posts should be fully rendered at once)
      # The posts that are far from the viewport should have the "post-stream--cloaked" class
      expect(post_stream).to have_css(".post-stream--cloaked")

      # Get the number of the last post
      last_post_number = topic.highest_post_number

      # Scroll to the bottom of the page to load more posts
      # We use the :end key to scroll to the bottom
      send_keys(:end)

      # Verify that the last post is not cloaked
      expect(post_stream).to have_no_css(
        "> [data-post-number='#{last_post_number}'].post-stream--cloaked",
      )

      # Verify that some posts at the top are now cloaked
      # we can check the first post to see if it's cloaked
      expect(post_stream).to have_css("> [data-post-number='1'].post-stream--cloaked")
    end

    it "keeps the state of quoted posts after uncloaking them" do
      first_post = posts[0]
      second_post = posts[1]
      second_post.raw =
        "[quote=\"#{first_post.user.username}, post:1, topic:#{topic.id}\"]\nHello\n[/quote]\n#{first_post.raw}"

      # Rebake the post to process the quote markup
      second_post.rebake!

      # Visit the topic page
      visit "/t/#{topic.slug}/#{topic.id}/1"

      post2_selector = "[data-post-number='2']"

      # Find the post-stream container
      post_stream = find(".post-stream")

      # Verify the second post is initially visible (uncloaked)
      expect(post_stream).to have_css(post2_selector)
      expect(post_stream).to have_no_css("#{post2_selector}.post-stream--cloaked")

      # Verify the quote starts collapsed
      expect(post_stream).to have_css("#{post2_selector} aside.quote[data-expanded='false']")

      # Find the blockquote and verify the initial state
      blockquote = post_stream.find("#{post2_selector} aside.quote blockquote")
      expect(blockquote).to have_content("Hello")
      expect(blockquote).to have_no_content(first_post.raw)

      # Expand the quote by clicking the toggle button
      post_stream.find(
        "#{post2_selector} aside.quote[data-expanded='false'] button.quote-toggle",
      ).click
      expect(post_stream).to have_css("#{post2_selector} aside.quote[data-expanded='true']")

      # Verify the expanded quote shows full content
      blockquote = post_stream.find("#{post2_selector} aside.quote blockquote")
      expect(blockquote).to have_content(first_post.raw)

      # Scroll to bottom to trigger post cloaking
      send_keys(:end)

      # Verify that the second post gets cloaked and the quote is removed
      expect(post_stream).to have_css("#{post2_selector}.post-stream--cloaked")
      expect(post_stream).to have_no_css("#{post2_selector} aside.quote")

      # Scroll back to top
      send_keys(:home)

      # Verify that the second post becomes visible again
      expect(post_stream).to have_css(post2_selector)
      expect(post_stream).to have_no_css("#{post2_selector}.post-stream--cloaked")

      # Verify that the quote maintains an expanded state after uncloaking
      expect(post_stream).to have_css("#{post2_selector} aside.quote[data-expanded='true']")
      blockquote = post_stream.find("#{post2_selector} aside.quote blockquote")
      expect(blockquote).to have_content(first_post.raw)
    end
  end
end
