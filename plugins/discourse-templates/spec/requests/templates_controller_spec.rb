# frozen_string_literal: true

require_relative "../helpers/topics_helper"

RSpec.configure { |c| c.include DiscourseTemplates::TopicsHelper }

describe DiscourseTemplates::TemplatesController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:user_in_group1) { Fabricate(:user) }
  fab!(:user_in_group2) { Fabricate(:user) }
  fab!(:group1) do
    group = Fabricate(:group)
    group.add(user_in_group1)
    group.save
    group
  end
  fab!(:group2) do
    group = Fabricate(:group)
    group.add(user_in_group2)
    group.save
    group
  end
  fab!(:templates_parent_category) { Fabricate(:category_with_definition) }
  fab!(:templates_other_parent_category) { Fabricate(:category_with_definition) }
  fab!(:templates_sub_category_moderators) do
    Fabricate(
      :private_category_with_definition,
      parent_category_id: templates_parent_category.id,
      group: Group[:moderators],
    )
  end
  fab!(:templates_sub_category_group) do
    Fabricate(
      :private_category_with_definition,
      parent_category_id: templates_parent_category.id,
      group: group1,
    )
  end
  fab!(:templates_sub_category_group2) do
    Fabricate(
      :private_category_with_definition,
      parent_category_id: templates_parent_category.id,
      group: group2,
    )
  end
  fab!(:templates_sub_category_everyone) do
    Fabricate(:category_with_definition, parent_category_id: templates_parent_category.id)
  end
  fab!(:template_item0) { Fabricate(:template_item, category: templates_parent_category) }
  fab!(:template_item1) { Fabricate(:template_item, category: templates_parent_category) }
  fab!(:template_item2) { Fabricate(:template_item, category: templates_parent_category) }
  fab!(:template_item3) { Fabricate(:template_item, category: templates_sub_category_moderators) }
  fab!(:template_item4) { Fabricate(:template_item, category: templates_sub_category_group) }
  fab!(:template_item5) { Fabricate(:template_item, category: templates_sub_category_group2) }
  fab!(:template_item6) { Fabricate(:template_item, category: templates_sub_category_everyone) }
  fab!(:template_item7) { Fabricate(:template_item, category: templates_sub_category_everyone) }
  fab!(:template_item_from_other_parent) do
    Fabricate(:template_item, category: templates_other_parent_category)
  end
  fab!(:other_topic1) { Fabricate(:template_item) } # uncategorized
  fab!(:other_topic2) { Fabricate(:template_item) } # uncategorized
  fab!(:other_topic3) { Fabricate(:template_item) } # uncategorized
  fab!(:tag) do
    Fabricate(
      :tag,
      topics: [template_item4],
      categories: [templates_sub_category_moderators],
      name: "category-tag",
    )
  end
  fab!(:everyone_tag) do
    Fabricate(
      :tag,
      topics: [template_item0, template_item1, template_item2, template_item6, template_item7],
      name: "use-anywhere",
    )
  end
  fab!(:group_tag) { Fabricate(:tag, topics: [template_item4, template_item5], name: "use-group") }

  before { SiteSetting.discourse_templates_enabled = true }

  describe "#list" do
    context "when a regular user is logged" do
      before { sign_in(user) }

      it "should list topics in the category assigned as templates" do
        SiteSetting.discourse_templates_categories = templates_sub_category_everyone.id.to_s

        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expected_response = serialize_topics([template_item6, template_item7].sort_by(&:title))

        expect(parsed["templates"]).to eq(expected_response)
      end

      it "should list topics from multiple parent categories" do
        SiteSetting.discourse_templates_categories = [
          templates_sub_category_everyone,
          templates_other_parent_category,
        ].map(&:id).join("|")

        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expected_response =
          serialize_topics(
            [template_item6, template_item7, template_item_from_other_parent].sort_by(&:title),
          )

        expect(parsed["templates"]).to eq(expected_response)
      end

      it "should list topics in the parent category and subcategories that the user can see" do
        SiteSetting.discourse_templates_categories = templates_parent_category.id.to_s

        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expected_response =
          serialize_topics(
            [
              template_item0,
              template_item1,
              template_item2,
              template_item6,
              template_item7,
            ].sort_by(&:title),
          )

        expect(parsed["templates"]).to eq(expected_response)
      end

      it "should not be able to use templates if can't see topics in the category" do
        SiteSetting.discourse_templates_categories = templates_sub_category_moderators.id.to_s

        get "/discourse_templates"
        expect(response.status).to eq(403)

        SiteSetting.discourse_templates_categories = templates_sub_category_group.id.to_s

        get "/discourse_templates"
        expect(response.status).to eq(403)

        SiteSetting.discourse_templates_categories = templates_sub_category_group2.id.to_s

        get "/discourse_templates"
        expect(response.status).to eq(403)
      end
    end

    context "when a moderator is logged" do
      before do
        Group.refresh_automatic_groups!(:moderators)
        sign_in(moderator)
      end

      it "should list topics in the parent category and subcategories that the moderator can see" do
        SiteSetting.discourse_templates_categories = [
          templates_parent_category,
          templates_other_parent_category,
        ].map(&:id).join("|")

        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expected_response =
          serialize_topics(
            [
              template_item0,
              template_item1,
              template_item2,
              template_item3,
              template_item6,
              template_item7,
              template_item_from_other_parent,
            ].sort_by(&:title),
          )

        expect(parsed["templates"]).to eq(expected_response)
      end
    end

    context "when an user belonging to a group is logged" do
      it "should list topics in the parent category and subcategories that the user can see" do
        SiteSetting.discourse_templates_categories = [
          templates_parent_category,
          templates_other_parent_category,
        ].map(&:id).join("|")

        sign_in(user_in_group1)

        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expected_response =
          serialize_topics(
            [
              template_item0,
              template_item1,
              template_item2,
              template_item4,
              template_item6,
              template_item7,
              template_item_from_other_parent,
            ].sort_by(&:title),
          )

        expect(parsed["templates"]).to eq(expected_response)

        sign_in(user_in_group2)

        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expected_response =
          serialize_topics(
            [
              template_item0,
              template_item1,
              template_item2,
              template_item5,
              template_item6,
              template_item7,
              template_item_from_other_parent,
            ].sort_by(&:title),
          )

        expect(parsed["templates"]).to eq(expected_response)
      end
    end

    context "when an admin is logged" do
      before do
        SiteSetting.discourse_templates_categories = [
          templates_parent_category,
          templates_other_parent_category,
        ].map(&:id).join("|")

        sign_in(admin)
        Group.refresh_automatic_groups!
      end

      it "should list topics in the parent category and subcategories that the admin can see" do
        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expected_response =
          serialize_topics(
            [
              template_item0,
              template_item1,
              template_item2,
              template_item3,
              template_item4,
              template_item5,
              template_item6,
              template_item7,
              template_item_from_other_parent,
            ].sort_by(&:title),
          )

        expect(parsed["templates"]).to eq(expected_response)
      end

      it "should not list delete, archived and unlisted topics" do
        template_item0.trash!(admin)
        expect(template_item0.deleted_at).not_to eq(nil)

        template_item1.update_attribute :archived, true
        expect(template_item1).to be_archived

        template_item2.update_status("visible", false, admin)
        template_item2.reload
        expect(template_item2).not_to be_visible

        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expected_response =
          serialize_topics(
            [
              template_item3,
              template_item4,
              template_item5,
              template_item6,
              template_item7,
              template_item_from_other_parent,
            ].sort_by(&:title),
          )

        expect(parsed["templates"]).to eq(expected_response)
      end
    end

    context "when no user is signed in" do
      it "should return 404" do
        SiteSetting.discourse_templates_categories = templates_sub_category_everyone.id.to_s

        get "/discourse_templates"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#use" do
    describe "check if the id received belongs to a template" do
      before do
        SiteSetting.discourse_templates_categories = templates_parent_category.id.to_s

        sign_in(admin)
        Group.refresh_automatic_groups!
      end

      it "should return 422 when id does not belong to a valid topic" do
        # to avoid flaky testing we create a topic and immediately destroy it to obtain
        # an invalid topic id
        invalid_topic_id = Fabricate(:template_item).tap(&:destroy!).id

        post "/discourse_templates/#{invalid_topic_id}/use"
        expect(response.status).to eq(422)
      end

      it "should return 422 when topic does not belong to template category or its subcategories" do
        post "/discourse_templates/#{other_topic1.id}/use"
        expect(response.status).to eq(422)
      end

      it "should return 200 if the topic belongs to the templates category" do
        post "/discourse_templates/#{template_item0.id}/use"
        expect(response.status).to eq(200)
      end

      it "should return 200 if the topic belongs to the templates subcategories" do
        post "/discourse_templates/#{template_item3.id}/use"
        expect(response.status).to eq(200)

        post "/discourse_templates/#{template_item4.id}/use"
        expect(response.status).to eq(200)

        post "/discourse_templates/#{template_item5.id}/use"
        expect(response.status).to eq(200)

        post "/discourse_templates/#{template_item6.id}/use"
        expect(response.status).to eq(200)
      end
    end

    context "when a template is used" do
      before do
        SiteSetting.discourse_templates_categories = templates_sub_category_moderators.id.to_s

        Group.refresh_automatic_groups!(:moderators)
        sign_in(moderator)
      end

      it "should increment usage count" do
        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body
        expected_response = serialize_topics([template_item3])

        expect(parsed["templates"]).to eq(expected_response)
        expect(parsed["templates"][0]["usages"]).to eq(0)

        post "/discourse_templates/#{template_item3.id}/use"
        expect(response.status).to eq(200)

        get "/discourse_templates"
        expect(response.status).to eq(200)

        parsed = response.parsed_body

        template_item3.reload
        expected_response = serialize_topics([template_item3])

        expect(parsed["templates"]).to eq(expected_response)
        expect(parsed["templates"][0]["usages"]).to eq(1)
      end
    end
  end
end
