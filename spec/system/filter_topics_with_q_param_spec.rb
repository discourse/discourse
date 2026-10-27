# frozen_string_literal: true

describe "Filtering topic lists with the q= parameter" do
  fab!(:category)
  fab!(:tag)

  fab!(:open_topic) { Fabricate(:topic, category: category) }
  fab!(:closed_topic) { Fabricate(:topic, category: category, closed: true) }
  fab!(:open_tagged_topic) { Fabricate(:topic, category: category, tags: [tag]) }
  fab!(:closed_tagged_topic) { Fabricate(:topic, category: category, closed: true, tags: [tag]) }

  let(:discovery) { PageObjects::Pages::Discovery.new }

  context "when on a category page" do
    it "applies the q= DSL as an AND filter on top of the category scope" do
      visit("/c/#{category.slug}/#{category.id}/l/latest?q=status%3Aopen")

      expect(discovery.topic_list).to have_topic(open_topic)
      expect(discovery.topic_list).to have_topic(open_tagged_topic)
      expect(discovery.topic_list).to have_no_topic(closed_topic)
      expect(discovery.topic_list).to have_no_topic(closed_tagged_topic)
    end

    it "shows only closed topics when q=status:closed is applied" do
      visit("/c/#{category.slug}/#{category.id}/l/latest?q=status%3Aclosed")

      expect(discovery.topic_list).to have_topic(closed_topic)
      expect(discovery.topic_list).to have_topic(closed_tagged_topic)
      expect(discovery.topic_list).to have_no_topic(open_topic)
      expect(discovery.topic_list).to have_no_topic(open_tagged_topic)
    end
  end

  context "when on a tag page" do
    it "applies the q= DSL as an AND filter on top of the tag scope" do
      visit("/tag/#{tag.name}/l/latest?q=status%3Aopen")

      expect(discovery.topic_list).to have_topic(open_tagged_topic)
      expect(discovery.topic_list).to have_no_topic(closed_tagged_topic)
      expect(discovery.topic_list).to have_no_topic(open_topic)
    end

    it "shows only closed tagged topics when q=status:closed is applied" do
      visit("/tag/#{tag.name}/l/latest?q=status%3Aclosed")

      expect(discovery.topic_list).to have_topic(closed_tagged_topic)
      expect(discovery.topic_list).to have_no_topic(open_tagged_topic)
      expect(discovery.topic_list).to have_no_topic(open_topic)
    end
  end
end
