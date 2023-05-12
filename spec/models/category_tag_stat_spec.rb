# frozen_string_literal: true

describe CategoryTagStat do
  fab!(:category) { Fabricate(:category) }
  fab!(:tag) { Fabricate(:tag) }
  fab!(:topic) { Fabricate(:topic, category: category, tags: [tag]) }

  describe "#update_topic_counts" do
    it "creates new records" do
      CategoryTagStat.destroy_all

      expect { CategoryTagStat.update_topic_counts }.to change { CategoryTagStat.count }.by(1)
      category_tag_stat = CategoryTagStat.last
      expect(category_tag_stat.category_id).to eq(category.id)
      expect(category_tag_stat.tag_id).to eq(tag.id)
      expect(category_tag_stat.topic_count).to eq(1)
    end

    it "updates existing records" do
      CategoryTagStat.last.update(topic_count: 10)

      expect { CategoryTagStat.update_topic_counts }.not_to change { CategoryTagStat.count }
      category_tag_stat = CategoryTagStat.last
      expect(category_tag_stat.category_id).to eq(category.id)
      expect(category_tag_stat.tag_id).to eq(tag.id)
      expect(category_tag_stat.topic_count).to eq(1)
    end

    it "deletes old records" do
      CategoryTagStat.last.update(tag_id: Fabricate(:tag).id)

      expect { CategoryTagStat.update_topic_counts }.not_to change { CategoryTagStat.count }
      category_tag_stat = CategoryTagStat.last
      expect(category_tag_stat.category_id).to eq(category.id)
      expect(category_tag_stat.tag_id).to eq(tag.id)
      expect(category_tag_stat.topic_count).to eq(1)
    end
  end
end
