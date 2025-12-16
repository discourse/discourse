# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::MostViewedCategories do
  fab!(:date) { Date.new(2021).all_year }
  fab!(:user)
  fab!(:other_user, :user)

  fab!(:category_1) { Fabricate(:category, name: "Technology") }
  fab!(:category_2) { Fabricate(:category, name: "Science") }
  fab!(:category_3) { Fabricate(:category, name: "Philosophy") }
  fab!(:category_4) { Fabricate(:category, name: "Literature") }
  fab!(:category_5) { Fabricate(:category, name: "History") }

  fab!(:topic_1) { Fabricate(:topic, category: category_1) }
  fab!(:topic_2) { Fabricate(:topic, category: category_1) }
  fab!(:topic_3) { Fabricate(:topic, category: category_2) }
  fab!(:topic_4) { Fabricate(:topic, category: category_3) }
  fab!(:topic_5) { Fabricate(:topic, category: category_4) }
  fab!(:topic_6) { Fabricate(:topic, category: category_5) }

  before { SiteSetting.discourse_rewind_enabled = true }

  describe ".call" do
    it "returns top 4 most viewed categories ordered by view count" do
      # Category 1: 2 views
      TopicViewItem.add(topic_1.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
      TopicViewItem.add(topic_2.id, "127.0.0.2", user.id, Date.new(2021, 4, 20))

      # Category 2: 1 view
      TopicViewItem.add(topic_3.id, "127.0.0.3", user.id, Date.new(2021, 5, 10))

      # Category 3: 1 view
      TopicViewItem.add(topic_4.id, "127.0.0.4", user.id, Date.new(2021, 6, 5))

      # Category 4: 3 views (same topic, multiple views)
      TopicViewItem.add(topic_5.id, "127.0.0.5", user.id, Date.new(2021, 7, 1))
      TopicViewItem.add(topic_5.id, "127.0.0.6", user.id, Date.new(2021, 8, 15))
      TopicViewItem.add(topic_5.id, "127.0.0.7", user.id, Date.new(2021, 9, 20))

      # Category 5: 0 views

      result = call_report

      expect(result[:identifier]).to eq("most-viewed-categories")
      expect(result[:data].length).to eq(4)
      expect(result[:data]).to eq(
        [
          { category_id: category_1.id, name: "Technology" },
          { category_id: category_2.id, name: "Science" },
          { category_id: category_3.id, name: "Philosophy" },
          { category_id: category_4.id, name: "Literature" },
        ],
      )
    end

    it "only includes categories the user can see (no read-restricted/private categories)" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      private_topic = Fabricate(:topic, category: private_category)

      TopicViewItem.add(private_topic.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))

      result = call_report
      expect(result[:data].map { |c| c[:category_id] }).not_to include(private_category.id)
    end

    it "filters by date range" do
      TopicViewItem.add(topic_1.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
      TopicViewItem.add(topic_2.id, "127.0.0.2", user.id, Date.new(2020, 12, 31))

      result = call_report

      expect(result[:data].length).to eq(1)
      expect(result[:data].first[:category_id]).to eq(category_1.id)
    end

    it "only counts views for the specific user" do
      TopicViewItem.add(topic_1.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
      TopicViewItem.add(topic_2.id, "127.0.0.2", other_user.id, Date.new(2021, 4, 20))

      result = call_report

      expect(result[:data].length).to eq(1)
      expect(result[:data].first[:category_id]).to eq(category_1.id)
    end

    it "returns empty array when no views" do
      result = call_report

      expect(result[:identifier]).to eq("most-viewed-categories")
      expect(result[:data]).to eq([])
    end

    describe "private categories" do
      fab!(:group)

      before do
        group.add(user)
        category_1.read_restricted = true
        category_1.set_permissions(group.id => :full)
        category_1.save!
      end

      it "does not return private categories even when the user has permission to see them" do
        TopicViewItem.add(topic_1.id, "127.0.0.1", user.id, Date.new(2021, 3, 15))
        TopicViewItem.add(topic_2.id, "127.0.0.2", user.id, Date.new(2021, 4, 20))
        result = call_report
        expect(result[:data]).to eq([])
      end
    end
  end
end
