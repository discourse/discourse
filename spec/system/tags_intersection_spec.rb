# frozen_string_literal: true

describe "Tags intersection", type: :system do
  let(:discovery) { PageObjects::Pages::Discovery.new }

  fab!(:category) { Fabricate(:category, name: "fruits") }

  fab!(:tag) { Fabricate(:tag, name: "sour") }
  fab!(:tag2) { Fabricate(:tag, name: "tangy") }
  fab!(:tag3) { Fabricate(:tag, name: "sweet") }

  fab!(:tagged_topic) { Fabricate(:topic, tags: [tag, tag2, tag3]) }
  fab!(:the_topic) { Fabricate(:topic, category:, tags: [tag, tag2, tag3]) }

  it "filters by category" do
    visit("/tags/intersection/sour/tangy?category=fruits")

    expect(page).to have_current_path("/tags/intersection/sour/tangy?category=fruits")
    expect(discovery.topic_list).to have_topic(the_topic)
    expect(discovery.topic_list).to have_topics(count: 1)

    visit("/")

    # Confirm that frontend transitions work as well,
    # even though UI doesn't support that
    page.execute_script <<~JS
      require("discourse/lib/url").default.routeTo("/tags/intersection/sour/tangy?category=fruits")
    JS

    expect(page).to have_current_path("/tags/intersection/sour/tangy?category=fruits")
    expect(discovery.topic_list).to have_topic(the_topic)
    expect(discovery.topic_list).to have_topics(count: 1)
  end

  it "shortens and redirects URLs" do
    visit("/tags/intersection/sour/tangy/sour")
    expect(page).to have_current_path("/tags/intersection/sour/tangy")

    visit("/tags/intersection/sour/tangy/sour/sour")
    expect(page).to have_current_path("/tags/intersection/sour/tangy")

    visit("/tags/intersection/sour/sour")
    expect(page).to have_current_path("/tag/#{tag.slug}/#{tag.id}")
  end

  it "removes duplicates from the additional tags list" do
    visit("/tags/intersection/sour/tangy/tangy")
    expect(page).to have_current_path("/tags/intersection/sour/tangy")

    visit("/tags/intersection/sour/tangy/tangy/tangy")
    expect(page).to have_current_path("/tags/intersection/sour/tangy")
  end

  it "navigates correctly when adding and removing tags from the intersection chooser" do
    visit("/tags/intersection/sour/tangy")

    chooser = PageObjects::Components::SelectKit.new(".tags-intersection-chooser")
    chooser.expand
    chooser.select_row_by_name("sweet")

    expect(page).to have_current_path("/tags/intersection/sour/tangy/sweet")
    expect(discovery.topic_list).to have_topics(count: 2)

    chooser.unselect_by_name("tangy")

    expect(page).to have_current_path("/tags/intersection/sour/sweet")
  end

  context "with capitalized tag names" do
    fab!(:cap_tag) { Fabricate(:tag, name: "Spicy") }
    fab!(:cap_tag2) { Fabricate(:tag, name: "Bitter") }
    fab!(:cap_tag3) { Fabricate(:tag, name: "Savory") }

    fab!(:cap_tagged_topic) { Fabricate(:topic, tags: [cap_tag, cap_tag2, cap_tag3]) }
    fab!(:cap_the_topic) { Fabricate(:topic, category:, tags: [cap_tag, cap_tag2, cap_tag3]) }

    it "displays tag names in the chooser and shows correct topics when adding and removing tags" do
      visit("/tags/intersection/#{cap_tag.slug}/#{cap_tag2.slug}")

      chooser = PageObjects::Components::SelectKit.new(".tags-intersection-chooser")
      expect(chooser).to have_selected_names("Spicy", "Bitter")
      expect(discovery.topic_list).to have_topics(count: 2)
      expect(discovery.topic_list).to have_topic(cap_tagged_topic)
      expect(discovery.topic_list).to have_topic(cap_the_topic)

      chooser.expand
      chooser.select_row_by_name("Savory")

      expect(page).to have_current_path("/tags/intersection/Spicy/Bitter/Savory")
      expect(chooser).to have_selected_names("Spicy", "Bitter", "Savory")
      expect(discovery.topic_list).to have_topics(count: 2)
      expect(discovery.topic_list).to have_topic(cap_tagged_topic)
      expect(discovery.topic_list).to have_topic(cap_the_topic)

      chooser.unselect_by_name("Bitter")

      expect(page).to have_current_path("/tags/intersection/Spicy/Savory")
      expect(chooser).to have_selected_names("Spicy", "Savory")
      expect(discovery.topic_list).to have_topics(count: 2)
    end

    it "navigates to canonical tag URL when removing tags down to one" do
      visit("/tags/intersection/#{cap_tag.slug}/#{cap_tag2.slug}")

      chooser = PageObjects::Components::SelectKit.new(".tags-intersection-chooser")
      chooser.unselect_by_name("Bitter")

      expect(page).to have_current_path("/tag/#{cap_tag.slug}/#{cap_tag.id}")
      expect(discovery.topic_list).to have_topic(cap_tagged_topic)
      expect(discovery.topic_list).to have_topic(cap_the_topic)
    end
  end
end
