# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicCategory::V1 do
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category: category) }

  describe "#execute" do
    let(:item) { { "json" => {} } }

    it "moves the topic to the given category" do
      config = { "topic_id" => topic.id.to_s, "category_id" => other_category.id.to_s }

      result = execute_node(configuration: config, item: item)

      expect(result["topic_id"]).to eq(topic.id)
      expect(result["category_id"]).to eq(other_category.id)
      expect(result["old_category_id"]).to eq(category.id)
      expect(topic.reload.category_id).to eq(other_category.id)
    end

    it "accepts an integer category value" do
      config = { "topic_id" => topic.id.to_s, "category_id" => other_category.id }

      execute_node(configuration: config, item: item)

      expect(topic.reload.category_id).to eq(other_category.id)
    end

    it "moves the topic to the uncategorized category when the category is blank" do
      SiteSetting.allow_uncategorized_topics = true

      config = { "topic_id" => topic.id.to_s, "category_id" => "" }

      result = execute_node(configuration: config, item: item)

      expect(result["category_id"]).to eq(SiteSetting.uncategorized_category_id)
      expect(topic.reload.category_id).to eq(SiteSetting.uncategorized_category_id)
    end

    it "succeeds without changes when the topic is already in the category" do
      config = { "topic_id" => topic.id.to_s, "category_id" => category.id.to_s }

      result = execute_node(configuration: config, item: item)

      expect(result["category_id"]).to eq(category.id)
      expect(result["old_category_id"]).to eq(category.id)
      expect(topic.reload.category_id).to eq(category.id)
    end

    it "raises when the topic does not exist" do
      config = { "topic_id" => "-1", "category_id" => other_category.id.to_s }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises when the category does not exist" do
      config = { "topic_id" => topic.id.to_s, "category_id" => "-1" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises when clearing the category while uncategorized topics are disabled" do
      SiteSetting.allow_uncategorized_topics = false

      config = { "topic_id" => topic.id.to_s, "category_id" => "" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "This site does not allow topics without a category.",
      )
      expect(topic.reload.category_id).to eq(category.id)
    end

    it "raises for private message topics" do
      pm_topic = Fabricate(:private_message_topic)

      config = { "topic_id" => pm_topic.id.to_s, "category_id" => other_category.id.to_s }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "Personal messages cannot have a category.",
      )
      expect(pm_topic.reload.category_id).to be_nil
    end

    context "with a non-staff actor" do
      fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:author_topic) { Fabricate(:topic, user: author, category: category) }

      it "allows moving own topic to an allowed category" do
        config = {
          "topic_id" => author_topic.id.to_s,
          "category_id" => other_category.id.to_s,
          "actor_username" => author.username,
        }

        result = execute_node(configuration: config, item: item)

        expect(result["category_id"]).to eq(other_category.id)
        expect(author_topic.reload.category_id).to eq(other_category.id)
      end

      it "prevents moving another user's topic" do
        other_user = Fabricate(:user, refresh_auto_groups: true)
        config = {
          "topic_id" => author_topic.id.to_s,
          "category_id" => other_category.id.to_s,
          "actor_username" => other_user.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          Discourse::InvalidAccess,
        )
        expect(author_topic.reload.category_id).to eq(category.id)
      end

      it "prevents moving a topic to a restricted category" do
        staff_category = Fabricate(:private_category, group: Group[:staff])
        config = {
          "topic_id" => author_topic.id.to_s,
          "category_id" => staff_category.id.to_s,
          "actor_username" => author.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          Discourse::InvalidAccess,
        )
        expect(author_topic.reload.category_id).to eq(category.id)
      end
    end
  end
end
