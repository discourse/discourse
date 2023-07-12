# frozen_string_literal: true

describe "Viewing sidebar as anonymous user", type: :system do
  fab!(:tag1) do
    Fabricate(:tag, name: "tag 1").tap { |tag| Fabricate.times(1, :topic, tags: [tag]) }
  end

  fab!(:tag2) do
    Fabricate(:tag, name: "tag 2").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
  end

  fab!(:tag3) do
    Fabricate(:tag, name: "tag 3").tap { |tag| Fabricate.times(3, :topic, tags: [tag]) }
  end

  fab!(:tag4) do
    Fabricate(:tag, name: "tag 4").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
  end

  fab!(:tag5) do
    Fabricate(:tag, name: "tag 5").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
  end

  fab!(:tag6) do
    Fabricate(:tag, name: "tag 6").tap { |tag| Fabricate.times(1, :topic, tags: [tag]) }
  end

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  describe "when viewing the tags section" do
    it "should not display the tags section when tagging has been disabled" do
      SiteSetting.tagging_enabled = false

      visit("/latest")

      expect(sidebar).to have_no_tags_section
    end

    it "should not display the tags section when site has no top tags and `default_navigation_menu_tags` site setting has not been set" do
      Tag.delete_all

      visit("/latest")

      expect(sidebar).to have_no_tags_section
    end

    it "should display the site's top tags when `default_navigation_menu_tags` site setting has not been set" do
      visit("/latest")

      expect(sidebar).to have_tags_section
      expect(sidebar).to have_all_tags_section_link
      expect(sidebar).to have_tag_section_links([tag3, tag2, tag4, tag5, tag1])
    end

    it "should display the site's top tags when `default_navigation_menu_tags` site setting has been set but the tags configured are hidden to the user" do
      SiteSetting.default_navigation_menu_tags = "#{tag5.name}"
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag5.name])

      visit("/latest")

      expect(sidebar).to have_tags_section
      expect(sidebar).to have_all_tags_section_link
      expect(sidebar).to have_tag_section_links([tag3, tag2, tag4, tag1, tag6])
    end

    it "should display the tags configured in `default_navigation_menu_tags` site setting when it has been set" do
      SiteSetting.default_navigation_menu_tags = "#{tag3.name}|#{tag4.name}"

      visit("/latest")

      expect(sidebar).to have_tags_section
      expect(sidebar).to have_all_tags_section_link
      expect(sidebar).to have_tag_section_links([tag3, tag4])
    end
  end
end
