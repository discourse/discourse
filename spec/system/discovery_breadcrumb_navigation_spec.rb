# frozen_string_literal: true

describe "Navigating with breadcrumbs", type: :system do
  let(:discovery) { PageObjects::Pages::Discovery.new }

  fab!(:category1) { Fabricate(:category) }
  fab!(:c1_topic) { Fabricate(:topic, category: category1) }

  fab!(:category2) { Fabricate(:category) }
  fab!(:c2_topic) { Fabricate(:topic, category: category2) }
  fab!(:category2_child) { Fabricate(:category, parent_category: category2) }
  fab!(:c2_child_topic) { Fabricate(:topic, category: category2_child) }

  fab!(:category3) { Fabricate(:category, default_list_filter: "none") }
  fab!(:c3_topic) { Fabricate(:topic, category: category3) }
  fab!(:category3_child) { Fabricate(:category, parent_category: category3) }
  fab!(:c3_child_topic) { Fabricate(:topic, category: category3_child) }

  it "can navigate between categories" do
    visit("/c/#{category1.id}")

    expect(page).to have_current_path("/c/#{category1.slug}/#{category1.id}")
    expect(discovery.topic_list).to have_topic(c1_topic)
    expect(discovery.topic_list).to have_topics(count: 1)

    expect(discovery.category_drop).to have_selected_value(category1.id)
    discovery.category_drop.select_row_by_value(category2.id)

    expect(page).to have_current_path("/c/#{category2.slug}/#{category2.id}")
    expect(discovery.topic_list).to have_topic(c2_topic)
    expect(discovery.topic_list).to have_topic(c2_child_topic)
    expect(discovery.topic_list).to have_topics(count: 2)

    # When using breadcrumbs for navigation, default_list_filter does not apply
    discovery.category_drop.select_row_by_value(category3.id)
    expect(discovery.topic_list).to have_topic(c3_topic)
    expect(discovery.topic_list).to have_topic(c3_child_topic)
    expect(discovery.topic_list).to have_topics(count: 2)

    expect(discovery.subcategory_drop).to have_selected_value("") # all

    discovery.subcategory_drop.select_row_by_value("no-categories")
    expect(discovery.topic_list).to have_topic(c3_topic)
    expect(discovery.topic_list).to have_topics(count: 1)

    discovery.subcategory_drop.select_row_by_value(category3_child.id)
    expect(discovery.topic_list).to have_topic(c3_child_topic)
    expect(discovery.topic_list).to have_topics(count: 1)
  end

  context "with tags" do
    fab!(:tag) { Fabricate(:tag) }
    fab!(:c1_topic_tagged) { Fabricate(:topic, category: category1, tags: [tag]) }
    fab!(:c3_topic_tagged) { Fabricate(:topic, category: category3, tags: [tag]) }
    fab!(:c3_child_topic_tagged) { Fabricate(:topic, category: category3_child, tags: [tag]) }

    it "can filter by tags" do
      visit("/c/#{category1.id}")
      expect(page).to have_current_path("/c/#{category1.slug}/#{category1.id}")
      expect(discovery.topic_list).to have_topic(c1_topic)
      expect(discovery.topic_list).to have_topic(c1_topic_tagged)
      expect(discovery.topic_list).to have_topics(count: 2)

      expect(discovery.tag_drop).to have_selected_name("all tags")
      discovery.tag_drop.select_row_by_value(tag.name)

      expect(discovery.topic_list).to have_topics(count: 1)
      expect(discovery.topic_list).to have_topic(c1_topic_tagged)
    end

    it "maintains no-subcategories option" do
      visit("/c/#{category3.slug}/#{category3.id}/none")
      expect(discovery.topic_list).to have_topic(c3_topic)
      expect(discovery.topic_list).to have_topic(c3_topic_tagged)
      expect(discovery.topic_list).to have_topics(count: 2)

      expect(discovery.subcategory_drop).to have_selected_name("none")
      expect(discovery.tag_drop).to have_selected_name("all tags")
      discovery.tag_drop.select_row_by_value(tag.name)

      expect(page).to have_current_path(
        "/tags/c/#{category3.slug}/#{category3.id}/none/#{tag.name}",
      )
      expect(discovery.topic_list).to have_topics(count: 1)
      expect(discovery.topic_list).to have_topic(c3_topic_tagged)
    end
  end

  describe "initial page loads for no-subcategories" do
    it "shows correct data for /c/" do
      visit("/c/#{category3.id}")
      expect(page).to have_current_path("/c/#{category3.slug}/#{category3.id}/none")
      expect(discovery.topic_list).to have_topic(c3_topic)
      expect(discovery.topic_list).to have_topics(count: 1)
    end

    it "shows correct data for /tags/c/" do
      tag = Fabricate(:tag)
      c3_topic.update!(tags: [tag])
      c3_child_topic.update!(tags: [tag])

      visit("/tags/c/#{category3.slug}/#{category3.id}/#{tag.name}")
      expect(page).to have_current_path(
        "/tags/c/#{category3.slug}/#{category3.id}/none/#{tag.name}",
      )
      expect(discovery.topic_list).to have_topic(c3_topic)
      expect(discovery.topic_list).to have_topics(count: 1)
    end
  end
end
