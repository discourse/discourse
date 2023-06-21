# frozen_string_literal: true

describe "Viewing top topics on categories page", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  let(:category_list) { PageObjects::Components::CategoryList.new }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }

  it "displays and updates new counter" do
    sign_in(user)

    visit("/categories")

    category_list.click_new_posts_badge(count: 1)
    category_list.click_topic(topic)
    category_list.click_logo
    category_list.click_category_navigation

    expect(category_list).to have_category(category)
    expect(category_list).to have_no_new_posts_badge
  end
end
