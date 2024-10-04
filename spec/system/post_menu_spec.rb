# frozen_string_literal: true

describe "Post menu", type: :system do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, reads: 5, like_count: 6) }
  fab!(:post2) { Fabricate(:post, user: user, topic: topic, like_count: 0) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  %w[enabled disabled].each do |value|
    before do
      SiteSetting.glimmer_post_menu_mode = value
      SiteSetting.post_menu = "like|copyLink|share|flag|edit|bookmark|delete|admin|reply"
      SiteSetting.post_menu_hidden_items = "flag|bookmark|edit|delete|admin"
    end

    context "when the Glimmer post menu is #{value}" do
      describe "general rendering" do
        before { sign_in(admin) }

        it "renders the expected buttons according to what is specified in the `post_menu`/`post_menu_hidden_items` settings" do
          [
            {
              # skip the read button because we're not viewing a PM
              post_menu: "like|copyLink|share|flag|edit|bookmark|delete|admin|reply",
              post_menu_hidden_items: "flag|bookmark|edit|delete|admin",
            },
            {
              post_menu: "like|copyLink|edit|bookmark|delete|admin|reply",
              post_menu_hidden_items: "flag|admin|edit",
            },
          ].each do |scenario|
            scenario => { post_menu:, post_menu_hidden_items: }

            SiteSetting.post_menu = post_menu
            SiteSetting.post_menu_hidden_items = post_menu_hidden_items

            topic_page.visit_topic(post.topic)

            available_buttons = %w[admin bookmark copyLink delete edit flag like read reply share]
            expected_buttons = SiteSetting.post_menu.split("|")
            hidden_buttons = SiteSetting.post_menu_hidden_items.split("|")
            visible_buttons = expected_buttons - hidden_buttons

            visible_buttons.each do |button|
              expect(topic_page).to have_post_action_button(post, button.to_sym)
            end
            hidden_buttons.each do |button|
              expect(topic_page).to have_no_post_action_button(post, button.to_sym)
            end

            # expand the items and check again if all expected buttons are visible now
            topic_page.expand_post_actions(post)
            expected_buttons.each do |button|
              expect(topic_page).to have_post_action_button(post, button.to_sym)
            end

            # check if the buttons are in the correct order
            node_elements = topic_page.find_post_action_buttons(post).all("*")
            button_node_positions =
              expected_buttons.map do |button|
                node_elements.find_index(topic_page.find_post_action_button(post, button.to_sym))
              end

            expect(button_node_positions).to eq(button_node_positions.compact.sort)

            # verify that buttons that weren't specified int the post_menu setting weren't rendered
            (available_buttons - expected_buttons).each do |button|
              expect(topic_page).to have_no_post_action_button(post, button.to_sym)
            end
          end
        end
      end

      describe "copy link" do
        let(:cdp) { PageObjects::CDP.new }

        before do
          sign_in(user)
          cdp.allow_clipboard
        end

        it "copies the absolute link to the post when clicked" do
          topic_page.visit_topic(post.topic)
          topic_page.click_post_action_button(post, :copy_link)
          cdp.clipboard_has_text?(post.full_url(share_url: true) + "?u=#{user.username}")
        end
      end

      describe "edit" do
        before do
          SiteSetting.edit_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
          SiteSetting.edit_wiki_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
          SiteSetting.post_menu_hidden_items = ""
        end

        it "displays the edit button only when the user can edit the post" do
          # do not display the edit button when unlogged
          topic_page.visit_topic(post.topic)

          expect(topic_page).to have_no_post_action_button(post, :edit)
          expect(topic_page).to have_no_post_action_button(post2, :edit)

          # display the edit button only for the post that `user` can edit
          sign_in(user)

          topic_page.visit_topic(post.topic)

          expect(topic_page).to have_no_post_action_button(post, :edit)
          expect(topic_page).to have_post_action_button(post2, :edit)

          # display the edit button for the all the posts because an admin is logged
          sign_in(admin)

          topic_page.visit_topic(post.topic)

          expect(topic_page).to have_post_action_button(post, :edit)
          expect(topic_page).to have_post_action_button(post2, :edit)
        end

        it "displays the edit button properly when the topic is a wiki" do
          wiki_topic = Fabricate(:topic)
          wiki_post = Fabricate(:post, topic: wiki_topic, user: Fabricate(:user), wiki: true)
          non_wiki_post = Fabricate(:post, topic: wiki_topic, user: Fabricate(:user), wiki: false)

          # do not display the edit button when unlogged
          topic_page.visit_topic(wiki_post.topic)

          expect(topic_page).to have_no_post_action_button(wiki_post, :edit)
          expect(topic_page).to have_no_post_action_button(non_wiki_post, :edit)

          # display the edit button only for the post that `user` can edit
          sign_in(user)

          topic_page.visit_topic(wiki_post.topic)

          expect(topic_page).to have_post_action_button(wiki_post, :edit)
          expect(topic_page).to have_no_post_action_button(non_wiki_post, :edit)
        end

        it "works as expected" do
          sign_in(user)

          topic_page.visit_topic(post2.topic)

          expect(composer).to be_closed
          topic_page.click_post_action_button(post2, :edit)

          expect(composer).to be_opened
          expect(composer).to have_content(post2.raw)
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
          try_until_success do
            like_button = topic_page.find_post_action_button(unliked_post, :like)
            expect(like_button[:class].split("\s")).to include("has-like")
          end

          like_count_button = topic_page.find_post_action_button(unliked_post, :like_count)
          expect(like_count_button).to have_content(1)

          # toggle the like off
          topic_page.click_post_action_button(unliked_post, :like)

          # we need this because the find_post_action_button will target the like button on or off
          try_until_success do
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

          expect(page).to have_css(".d-modal.login-modal")
        end

        it "renders the like count as expected" do
          topic_page.visit_topic(post.topic)

          # renders the like count when the it's not zero
          like_count_button = topic_page.find_post_action_button(post, :like_count)
          expect(like_count_button).to have_content(post.like_count)

          # does not render the like count when it's zero
          expect(topic_page).to have_no_post_action_button(post2, :like_count)
        end

        it "toggles the users who liked when clicking on the like count" do
          PostActionCreator.like(user, post)
          PostActionCreator.like(admin, post)

          topic_page.visit_topic(post.topic)

          expect(topic_page).to have_no_who_liked_on_post(post)

          # toggle users who liked on
          topic_page.click_post_action_button(post, :like_count)
          expect(topic_page).to have_who_liked_on_post(post, count: 2)

          # toggle users who liked off
          topic_page.click_post_action_button(post, :like_count)
          expect(topic_page).to have_no_who_liked_on_post(post)
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
    end
  end
end
