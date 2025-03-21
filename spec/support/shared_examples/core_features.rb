# frozen_string_literal: true

RSpec.shared_examples_for "having working core features" do |skip_examples: []|
  fab!(:category) { Fabricate(:category, name: "General") }
  fab!(:topics) { Fabricate.times(3, :topic_with_op, category:) }
  fab!(:topic)
  fab!(:active_user)

  let(:composer) { PageObjects::Components::Composer.new }

  if skip_examples.exclude?(:topics)
    describe "Topics" do
      context "with an anonymous user" do
        before { visit "/" }

        it "lists latest topics" do
          expect(page).to have_css(".topic-list-item", count: 4)
        end

        it "lists topics for a category" do
          within("#sidebar-section-content-categories") { click_on("General") }
          expect(page).to have_css(".topic-list-item", count: 3)
        end

        it "displays a specific topic" do
          click_on(topics.first.title)
          expect(page).to have_content(topics.first.title)
          expect(page).to have_content(topics.first.first_post.raw)
        end
      end

      context "with a logged in user" do
        before do
          sign_in(active_user)
          visit "/"
        end

        it "lists latest topics" do
          expect(page).to have_css(".topic-list-item", count: 4)
        end

        it "lists topics for a category" do
          within("#sidebar-section-content-categories") { click_on("General") }
          expect(page).to have_css(".topic-list-item", count: 3)
        end

        it "displays a specific topic" do
          click_on(topics.first.title)
          expect(page).to have_content(topics.first.title)
          expect(page).to have_content(topics.first.first_post.raw)
        end

        it "replies in a topic" do
          click_on(topics.first.title)
          expect(page).to have_content(topics.first.first_post.raw)
          within(".topic-footer-main-buttons") { click_button("Reply") }
          composer.focus
          send_keys("This is a long enough reply.")
          within(".save-or-cancel") { click_button("Reply") }
          expect(page).to have_content("This is a long enough reply.")
        end

        it "creates a new topic" do
          click_on("New Topic")
          composer.fill_title("This is a new topic")
          composer.fill_content("This is a long enough sentence.")
          within(".save-or-cancel") { click_button("Create Topic") }
          expect(page).to have_content("This is a new topic")
          expect(page).to have_content("This is a long enough sentence.")
        end
      end
    end
  end

  if skip_examples.exclude?(:likes)
    describe "Likes" do
      before do
        sign_in(active_user)
        visit "/"
      end

      it "likes a post" do
        click_on(topics.first.title)
        within(".double-button") do
          find(".toggle-like").click
          expect(page).to have_content("1")
        end
      end
    end
  end

  if skip_examples.exclude?(:profile)
    describe "User profile" do
      context "with an anonymous user" do
        it "displays a user’s profile"
      end

      context "with a logged in user" do
        it "displays a user’s profile"
        it "displays the user’s own profile"
      end
    end
  end

  if skip_examples.exclude?(:search)
    describe "Search" do
      context "with an anonymous user" do
        it "searches using the quick search"
        it "searches using the full page search"
      end

      context "with a logged in user" do
        it "searches using the quick search"
        it "searches using the full page search"
      end
    end
  end
end
