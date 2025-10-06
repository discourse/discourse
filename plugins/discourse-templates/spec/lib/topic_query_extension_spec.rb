# frozen_string_literal: true

require_relative "../helpers/topics_helper"

RSpec.configure { |c| c.include DiscourseTemplates::TopicsHelper }

describe DiscourseTemplates::TopicQueryExtension do
  fab!(:user)
  let!(:topic_query) do
    TopicQuery.new(user, per_page: SiteSetting.discourse_templates_max_replies_fetched.to_i)
  end

  describe "list_category_templates" do
    fab!(:other_category, :category_with_definition)
    fab!(:other_topics) { Fabricate.times(5, :topic, category: other_category) }
    fab!(:discourse_templates_category, :category_with_definition)
    fab!(:templates) do
      Fabricate.times(100, :template_item, category: discourse_templates_category)
    end

    before { SiteSetting.discourse_templates_categories = discourse_templates_category.id.to_s }

    let!(:topic_query) do
      TopicQuery.new(user, per_page: SiteSetting.discourse_templates_max_replies_fetched.to_i)
    end

    it "returns nil when user can't use category templates" do
      SiteSetting.discourse_templates_categories = ""
      expect(topic_query.list_category_templates).to be_nil
    end

    it "retrieves all topics in the category" do
      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size)
    end

    it "retrieves topics from multiple parent_categories" do
      SiteSetting.discourse_templates_categories = [
        discourse_templates_category,
        other_category,
      ].map(&:id).join("|")

      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size + other_topics.size)
    end

    it "filter out the category description topic" do
      expect(discourse_templates_category.topic_id).not_to eq(nil)

      topics = topic_query.list_category_templates.topics
      topics_without_category_description =
        topics.filter { |topic| topic.id != discourse_templates_category.topic_id }

      expect(topics.size).to eq(topics_without_category_description.size)
    end

    it "retrieves closed topics" do
      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size)

      closed_replies = templates.sample(templates.size * 0.2)
      closed_replies.each { |template| template.update_status("closed", true, user) }

      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size)
    end

    it "filter out unlisted topics" do
      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size)

      unlisted_replies = templates.sample(templates.size * 0.15)
      unlisted_replies.each { |template| template.update_status("visible", false, user) }

      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size - unlisted_replies.size)
    end

    it "filter out archived topics" do
      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size)

      archived_replies = templates.sample(templates.size * 0.25)
      archived_replies.each { |template| template.update_attribute :archived, true }

      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size - archived_replies.size)
    end

    it "filter out deleted topics" do
      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size)

      deleted_replies = templates.sample(templates.size * 0.2)
      deleted_replies.each { |template| template.trash! }

      topics = topic_query.list_category_templates.topics
      expect(topics.size).to eq(templates.size - deleted_replies.size)
    end

    it "sorts retrieved replies by title" do
      sorted_replies = templates.sort_by(&:title)

      # just to ensure the test sample isn't sorted because that would render the test after the
      # query to be useless
      templates.shuffle! if (templates == sorted_replies)

      topics = topic_query.list_category_templates.topics
      expect(topics).to eq(sorted_replies)
    end
  end

  describe "list_private_templates" do
    fab!(:user_a, :user)
    fab!(:user_b, :user)
    fab!(:group) do
      group = Fabricate(:group)
      Fabricate(:group_user, group: group, user: user)
      group
    end
    fab!(:other_group) do
      group = Fabricate(:group)
      Fabricate(:group_user, group: group, user: user_a)
      group
    end

    fab!(:tag_a) { Fabricate(:tag, name: "templates") }
    fab!(:tag_b) { Fabricate(:tag, name: "private-templates") }
    fab!(:private_templates_tag_a) do
      Fabricate.times(25, :private_template_item, user: user, tags: [tag_a])
    end
    fab!(:private_templates_tag_b) do
      Fabricate.times(18, :private_template_item, user: user, tags: [tag_b])
    end
    fab!(:private_messages_from_user_a) do
      Fabricate.times(5, :private_template_item, user: user_a, recipient: user, tags: [tag_a])
    end

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.discourse_templates_enable_private_templates = true
      SiteSetting.discourse_templates_groups_allowed_private_templates = group.id.to_s
      SiteSetting.discourse_templates_private_templates_tags = "private-templates|templates"
    end

    it "returns nil when user cannot use private templates" do
      SiteSetting.discourse_templates_enable_private_templates = false
      expect(topic_query.list_private_templates).to be_nil
    end

    it "returns nil if user do not belong to assigned group" do
      SiteSetting.discourse_templates_groups_allowed_private_templates = other_group.id.to_s
      # user wasn't added to the group so shouldn't be able to use private templates
      expect(topic_query.list_private_templates).to be_nil
    end

    it "returns empty if private messages do not belong to assigned tag" do
      SiteSetting.discourse_templates_private_templates_tags = "some_other_tag"
      expect(topic_query.list_private_templates.topics).to be_empty
    end

    it "retrieves all private templates in assigned tags" do
      topics = topic_query.list_private_templates.topics
      expect(topics.size).to eq(private_templates_tag_a.size + private_templates_tag_b.size)
    end

    it "retrieves only private messages in assigned tags as templates" do
      topics = topic_query.list_private_templates.topics
      expect(topics.size).to eq(private_templates_tag_a.size + private_templates_tag_b.size)

      # changing the tags that mark a private message as template should change the templates recovered
      SiteSetting.discourse_templates_private_templates_tags = "private-templates"

      topics = topic_query.list_private_templates.topics
      expect(topics.size).to eq(private_templates_tag_b.size)

      SiteSetting.discourse_templates_private_templates_tags = "templates"

      topics = topic_query.list_private_templates.topics
      expect(topics.size).to eq(private_templates_tag_a.size)

      # it shouldn't return any template if none of the tags match
      SiteSetting.discourse_templates_private_templates_tags = "other_unrelated_tag"

      topics = topic_query.list_private_templates.topics
      expect(topics.size).to eq(0)
    end

    it "won't list private messages received as templates" do
      topics = topic_query.list_private_templates.topics
      expect(((topics.map(&:id) & private_messages_from_user_a.map(&:id)).any?)).to eq(false)
    end
  end
end
