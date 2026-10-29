# frozen_string_literal: true

describe "Category pickers with the new select controls" do
  with_select_controls(true)

  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:gardening) { Fabricate(:category, name: "Gardening") }
  fab!(:cooking) { Fabricate(:category, name: "Cooking") }
  fab!(:tomatoes) { Fabricate(:category, name: "Tomatoes", parent_category: gardening) }
  fab!(:topic) { Fabricate(:topic, category: cooking, user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  def picker(selector)
    PageObjects::Components::UiKit::DSelect.at(selector)
  end

  def top_breadcrumb
    picker(".category-breadcrumb__category-selector")
  end

  describe "composer" do
    it "creates a topic in the picked category" do
      sign_in(user)
      visit "/new-topic"
      expect(composer).to be_opened

      composer.fill_title("Growing tomatoes on a small balcony")
      composer.fill_content("Which varieties do well in containers on a sunny balcony?")
      picker("#reply-control .category-input .category-chooser").select_value(tomatoes.id)
      composer.submit

      expect(topic_page).to have_topic_title("Growing tomatoes on a small balcony")
      expect(Topic.where(title: "Growing tomatoes on a small balcony").pick(:category_id)).to eq(
        tomatoes.id,
      )
    end
  end

  describe "topic edit" do
    it "moves the topic to the picked category" do
      sign_in(user)
      topic_page.visit_topic(topic)
      page.find(".edit-topic", visible: false).click

      picker(".edit-category__wrapper .category-chooser").select_value(gardening.id)
      find("#topic-title .submit-edit").click

      expect(page).to have_no_css("#topic-title .submit-edit")
      expect(topic.reload.category_id).to eq(gardening.id)
    end
  end

  describe "breadcrumbs" do
    it "routes to the picked category and its subcategories" do
      sign_in(user)
      visit "/latest"

      top_breadcrumb.select_value(gardening.id)
      expect(page).to have_current_path(gardening.url)

      picker(".category-breadcrumb__subcategory-selector").select_value("no-categories")
      expect(page).to have_current_path("#{gardening.url}/none")

      picker(".category-breadcrumb__subcategory-selector").select_value(tomatoes.id)
      expect(page).to have_current_path(tomatoes.url)
    end

    context "when categories load lazily" do
      before do
        SiteSetting.lazy_load_categories_groups = "admins"
        30.times { |i| Fabricate(:category, name: "Lazy category #{i}") }
      end

      it "reaches every category of a long level by scrolling" do
        sign_in(admin)
        visit "/latest"

        top_breadcrumb.open
        size = page.find(top_breadcrumb.option_selector, match: :first)["aria-setsize"].to_i
        expect(size).to be > 30
        try_until_success do
          top_breadcrumb.scroll_listbox_to_bottom
          expect(page).to have_css("[role='option'][aria-posinset='#{size}']", wait: 0)
        end
        expect(page).to have_no_css(".d-select__footer")
      end

      it "leaves out subcategories muted through their parent" do
        peppers = Fabricate(:category, name: "Peppers", parent_category: gardening)
        CategoryUser.create!(
          user: admin,
          category: gardening,
          notification_level: CategoryUser.notification_levels[:muted],
        )
        CategoryUser.create!(
          user: admin,
          category: peppers,
          notification_level: CategoryUser.notification_levels[:regular],
        )
        sign_in(admin)
        visit gardening.url

        subcategories = picker(".category-breadcrumb__subcategory-selector")
        subcategories.open
        expect(subcategories).to have_option_value(peppers.id)
        expect(subcategories).to have_no_option_value(tomatoes.id)
      end

      it "searches every category from the top level" do
        sign_in(admin)
        visit "/latest"

        top_breadcrumb.search("Tomatoes")
        expect(top_breadcrumb).to have_option_value(tomatoes.id)

        top_breadcrumb.select_value(tomatoes.id)
        expect(page).to have_current_path(tomatoes.url)
      end
    end
  end
end
