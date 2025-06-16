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
  end
end
