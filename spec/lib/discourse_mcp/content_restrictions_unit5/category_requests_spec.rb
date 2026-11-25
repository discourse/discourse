# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe CategoriesController, type: :request do
  include_context "with unit five content guards"

  fab!(:root) { Fabricate(:category_with_definition, id: 113_574_001, user: admin) }
  fab!(:outside) { Fabricate(:category, id: 113_574_002, user: admin) }

  describe "#update" do
    before { sign_in(admin) }

    %i[child grandchild branch].each do |shape|
      %i[outside top_level].each do |destination|
        it "[cr-u5] reports category errors when an admin moves a denied #{shape} to #{destination}" do
          child = Fabricate(:category, id: 113_574_010, parent_category: root, user: admin)
          grandchild = Fabricate(:category, id: 113_574_011, parent_category: child, user: admin)
          moving = shape == :grandchild ? grandchild : child
          grandchild.destroy! if shape == :child
          old_parent_id = moving.parent_category_id
          old_name = moving.name
          protect_targets(:deny, category_ids: [root.id])

          put "/categories/#{moving.id}.json",
              params: {
                parent_category_id: destination == :outside ? outside.id : "",
                name: "A denied move must also keep the original name",
              }

          aggregate_failures do
            expect(response.status).to eq(422), "CATEGORY MOVE: denied subtree escaped"
            expect_rule_explanation(Array(response.parsed_body["errors"]).join(" "))
            expect(moving.reload.parent_category_id).to eq(old_parent_id)
            expect(moving.name).to eq(old_name)
            expect(grandchild.reload.parent_category_id).to eq(child.id) if shape == :branch
          end
        end
      end
    end

    it "[cr-u5] refuses moving an existing denied grandchild after the nesting limit is lowered" do
      child = Fabricate(:category, parent_category: root, user: admin)
      grandchild = Fabricate(:category, parent_category: child, user: admin)
      protect_targets(:deny, category_ids: [root.id])
      SiteSetting.max_category_nesting = 2

      put "/categories/#{grandchild.id}.json", params: { parent_category_id: outside.id }

      aggregate_failures do
        expect(response.status).to eq(422), "CATEGORY MOVE: denied subtree escaped"
        expect_rule_explanation(Array(response.parsed_body["errors"]).join(" "))
        expect(grandchild.reload.parent_category_id).to eq(child.id)
      end
    end

    it "[cr-u5] lets an admin move a category into a denied subtree" do
      moving = Fabricate(:category, parent_category: outside, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { parent_category_id: root.id }

      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to eq(root.id)
    end

    it "[cr-u5] lets an admin move a category out of an allowed subtree" do
      moving = Fabricate(:category, parent_category: root, user: admin)
      protect_targets(:allow, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { parent_category_id: outside.id }

      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to eq(outside.id)
    end

    it "[cr-u5] lets an admin move a category into an allowed subtree" do
      moving = Fabricate(:category, parent_category: outside, user: admin)
      protect_targets(:allow, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { parent_category_id: root.id }

      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to eq(root.id)
    end

    it "[cr-u5] lets an admin move a denied category within the same denied subtree" do
      left = Fabricate(:category, parent_category: root, user: admin)
      right = Fabricate(:category, parent_category: root, user: admin)
      moving = Fabricate(:category, parent_category: left, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { parent_category_id: right.id }

      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to eq(right.id)
    end

    it "[cr-u5] lets an admin move a directly denied root with its subtree intact" do
      child = Fabricate(:category, parent_category: root, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      put "/categories/#{root.id}.json", params: { parent_category_id: outside.id }

      expect(response.status).to eq(200)
      expect(root.reload.parent_category_id).to eq(outside.id)
      expect(child.reload.parent_category_id).to eq(root.id)
    end

    it "[cr-u5] lets an admin rename a category inside a denied subtree" do
      moving = Fabricate(:category, parent_category: root, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { name: "Renamed safely inside the denied tree" }

      expect(response.status).to eq(200)
      expect(moving.reload.name).to eq("Renamed safely inside the denied tree")
      expect(moving.parent_category_id).to eq(root.id)
    end

    it "[cr-u5] lets an admin reparent and detach categories with no rules" do
      moving = Fabricate(:category, parent_category: root, user: admin)
      expect(McpContentRule.count).to eq(0)

      put "/categories/#{moving.id}.json", params: { parent_category_id: outside.id }
      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to eq(outside.id)

      put "/categories/#{moving.id}.json", params: { parent_category_id: "" }
      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to be_nil
    end
  end

  describe "#destroy" do
    before { sign_in(admin) }

    %i[allow deny].each do |side|
      it "[cr-u5] reports category errors when an admin deletes a directly #{side}-referenced category" do
        topic_id = root.topic_id
        post_id = root.topic.first_post.id
        protect_targets(side, category_ids: [root.id])

        delete "/categories/#{root.id}.json"

        aggregate_failures do
          expect(response.status).to eq(422), "CATEGORY DELETE: referenced category disappeared"
          expect_rule_explanation(Array(response.parsed_body["errors"]).join(" "))
          expect(Category.exists?(root.id)).to eq(true)
          expect(Topic.with_deleted.find(topic_id).deleted_at).to be_nil
          expect(Post.with_deleted.find(post_id).deleted_at).to be_nil
        end
      end
    end

    %i[child grandchild].each do |shape|
      it "[cr-u5] reports category errors when an admin deletes a #{shape} inside a denied subtree" do
        child = Fabricate(:category_with_definition, parent_category: root, user: admin)
        deleting =
          if shape == :grandchild
            Fabricate(:category_with_definition, parent_category: child, user: admin)
          else
            child
          end
        topic_id = deleting.topic_id
        protect_targets(:deny, category_ids: [root.id])

        delete "/categories/#{deleting.id}.json"

        aggregate_failures do
          expect(response.status).to eq(422), "CATEGORY DELETE: denied descendant disappeared"
          expect_rule_explanation(Array(response.parsed_body["errors"]).join(" "))
          expect(Category.exists?(deleting.id)).to eq(true)
          expect(Topic.with_deleted.find(topic_id).deleted_at).to be_nil
        end
      end
    end

    it "[cr-u5] refuses deleting an existing denied grandchild after the nesting limit is lowered" do
      child = Fabricate(:category, parent_category: root, user: admin)
      grandchild = Fabricate(:category_with_definition, parent_category: child, user: admin)
      topic_id = grandchild.topic_id
      protect_targets(:deny, category_ids: [root.id])
      SiteSetting.max_category_nesting = 2

      delete "/categories/#{grandchild.id}.json"

      aggregate_failures do
        expect(response.status).to eq(422), "CATEGORY DELETE: denied descendant disappeared"
        expect_rule_explanation(Array(response.parsed_body["errors"]).join(" "))
        expect(Category.exists?(grandchild.id)).to eq(true)
        expect(Topic.with_deleted.find(topic_id).deleted_at).to be_nil
      end
    end

    it "[cr-u5] lets an admin delete a category and soft-delete its definition with no rules" do
      topic_id = root.topic_id
      post_id = root.topic.first_post.id
      expect(McpContentRule.count).to eq(0)

      delete "/categories/#{root.id}.json"

      expect(response.status).to eq(200)
      expect(Category.exists?(root.id)).to eq(false)
      expect(Topic.with_deleted.find(topic_id).deleted_at).to be_present
      expect(Post.with_deleted.find(post_id).deleted_at).to be_present
    end

    it "[cr-u5] lets an admin delete an unreferenced category while another category is denied" do
      protect_targets(:deny, category_ids: [root.id])

      delete "/categories/#{outside.id}.json"

      expect(response.status).to eq(200)
      expect(Category.exists?(outside.id)).to eq(false)
      expect(Category.exists?(root.id)).to eq(true)
    end

    it "[cr-u5] lets an admin delete an unreferenced descendant of an allowed category" do
      child = Fabricate(:category_with_definition, parent_category: root, user: admin)
      protect_targets(:allow, category_ids: [root.id])

      delete "/categories/#{child.id}.json"

      expect(response.status).to eq(200)
      expect(Category.exists?(child.id)).to eq(false)
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
