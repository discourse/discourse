# frozen_string_literal: true

require_relative "./page_objects/components/user_color_palette_selector"

describe "Horizon theme | High level", type: :system do
  let!(:theme) do
    horizon_theme = upload_theme
    ColorScheme
      .where(theme_id: horizon_theme.id)
      .where.not("name LIKE '%Dark%'")
      .update_all(user_selectable: true)
    horizon_theme
  end
  fab!(:current_user) { Fabricate(:user) }
  fab!(:tag_1) { Fabricate(:tag, name: "wow-cool") }
  fab!(:tag_2) { Fabricate(:tag, name: "another-tag") }
  fab!(:category)
  fab!(:topic_1) { Fabricate(:topic_with_op, category: category, tags: [tag_1, tag_2]) }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:palette_selector) { PageObjects::Components::UserColorPaletteSelector.new }

  def run_all_high_level_tests
    expect(page).to have_css(".experimental-screen")

    expect(sidebar).to have_categories_section
    expect(sidebar).to have_section_link(category.name)

    expect(topic_list).to have_topic(topic_1)

    # Ensure the topic list columns are in the correct order via 'topic-list-columns' valueTransformer
    #
    # NOTE(martin): Maybe there is a better way to do this in a qunit test instead.
    topic_item = find(topic_list.topic_list_item_class(topic_1))
    expect(topic_item.all("td").map { |el| el["class"] }).to eq(
      [
        "main-link topic-list-data",
        "topic-category-data",
        "topic-creator-data",
        "topic-activity-data",
      ],
    )

    # Can see a topic in the list and navigate to it successfully.
    topic_list.visit_topic(topic_1)
    expect(topic_page).to have_topic_title(topic_1.title)

    # Can change site colors from the sidebar palette, which are remembered
    # across page reloads.
    marigold_palette = theme.color_schemes.find_by(name: "Marigold")
    palette_selector.open_palette_menu
    palette_selector.click_palette_menu_item(marigold_palette.name)
    expect(palette_selector).to have_no_palette_menu

    page.refresh
    expect(palette_selector).to have_selected_palette(marigold_palette)
    expect(palette_selector).to have_tertiary_color(marigold_palette)
  end

  it "works for anon" do
    visit "/"
    run_all_high_level_tests
  end

  context "for signed in users" do
    before { sign_in(current_user) }

    it "works" do
      visit "/"
      run_all_high_level_tests
    end
  end
end
