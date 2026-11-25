# frozen_string_literal: true

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe TagsController, type: :request do
  include_context "with MCP content rule targets"

  fab!(:tag) { Fabricate(:tag, id: 113_573_001, name: "u5-request-protected") }
  fab!(:other_tag) { Fabricate(:tag, id: 113_573_002, name: "u5-request-other") }

  describe "#destroy" do
    before { sign_in(admin) }

    %i[allow deny].each do |side|
      it "reports a content rule error to an admin deleting the #{side}-referenced tag" do
        topic = Fabricate(:topic, tags: [tag])
        protect_targets(side, tag_ids: [tag.id])

        delete "/tag/#{tag.name}.json"

        aggregate_failures do
          expect(response.status).to be_between(400, 499), "ADMIN TAG DELETE: returned success"
          expect_rule_explanation(Array(response.parsed_body["errors"]).join(" "))
          expect(Tag.exists?(tag.id)).to eq(true)
          expect(topic.reload.tags.pluck(:id)).to eq([tag.id])
        end
      end
    end

    it "lets an admin delete a tag with no rules" do
      expect(McpContentRule.count).to eq(0)

      delete "/tag/#{tag.name}.json"

      expect(response.status).to eq(200)
      expect(Tag.exists?(tag.id)).to eq(false)
    end

    it "lets an admin delete an unreferenced tag while another tag is protected" do
      protect_targets(:deny, tag_ids: [tag.id])

      delete "/tag/#{other_tag.name}.json"

      expect(response.status).to eq(200)
      expect(Tag.where(id: [tag.id, other_tag.id]).pluck(:id)).to eq([tag.id])
    end
  end

  describe "#create_synonyms" do
    before { sign_in(admin) }

    %i[allow deny].each do |side|
      %i[id name].each do |input|
        it "reports a failed tag for an admin converting the #{side}-referenced synonym by #{input}" do
          topic = Fabricate(:topic, tags: [tag])
          protect_targets(side, tag_ids: [tag.id])
          entry = input == :id ? { id: tag.id, name: tag.name } : { name: tag.name.upcase }

          post "/tag/#{other_tag.name}/synonyms.json", params: { tags: [entry] }

          aggregate_failures do
            expect(response.status).to eq(200)
            expect(response.parsed_body["failed"]).to eq("FAILED"),
            "ADMIN SYNONYM: referenced tag conversion succeeded"
            expect_rule_explanation(response.parsed_body.dig("failed_tags", tag.name).to_s)
            expect(tag.reload.target_tag_id).to be_nil
            expect(topic.reload.tags.pluck(:id)).to eq([tag.id])
          end
        end
      end
    end

    it "lets an admin convert a tag to a synonym with no rules" do
      expect(McpContentRule.count).to eq(0)

      post "/tag/#{other_tag.name}/synonyms.json", params: { tags: [{ id: tag.id }] }

      expect(response.status).to eq(200)
      expect(response.parsed_body["failed"]).to be_nil
      expect(tag.reload.target_tag_id).to eq(other_tag.id)
    end

    it "lets an admin add an unreferenced synonym to a protected target" do
      protect_targets(:deny, tag_ids: [other_tag.id])

      post "/tag/#{other_tag.name}/synonyms.json", params: { tags: [{ id: tag.id }] }

      expect(response.status).to eq(200)
      expect(response.parsed_body["failed"]).to be_nil
      expect(tag.reload.target_tag_id).to eq(other_tag.id)
    end
  end

  describe "#destroy_unused" do
    before { sign_in(admin) }

    %i[allow deny].each do |side|
      it "keeps a topicless #{side}-referenced tag while admin cleanup deletes an unused peer" do
        expect(tag.topics).to be_empty
        protect_targets(side, tag_ids: [tag.id])
        tag_ids = [tag.id, other_tag.id]
        protected_id = tag.id

        delete "/tags/unused.json"

        aggregate_failures do
          expect(response.status).to eq(200)
          expect(Tag.where(id: tag_ids).pluck(:id)).to eq([protected_id]),
          "ADMIN CLEANUP: referenced tag was deleted or unreferenced cleanup was blocked"
        end
      end
    end

    it "lets admin cleanup delete both unused tags with no rules" do
      expect(McpContentRule.count).to eq(0)
      tag_ids = [tag.id, other_tag.id]

      delete "/tags/unused.json"

      expect(response.status).to eq(200)
      expect(Tag.where(id: tag_ids)).to be_empty
    end
  end

  describe "#list_unused" do
    before { sign_in(admin) }

    %i[allow deny].each do |side|
      it "omits the #{side}-referenced tag from the admin unused-tag preview" do
        protect_targets(side, tag_ids: [tag.id])

        get "/tags/unused.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.fetch("tags") & [tag.name, other_tag.name]).to eq(
          [other_tag.name],
        ),
        "UNUSED PREVIEW: referenced tag is offered for deletion"
      end
    end

    it "previews both unused tags with no rules" do
      expect(McpContentRule.count).to eq(0)
      names = [tag.name, other_tag.name]

      get "/tags/unused.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("tags") & names).to contain_exactly(*names)
    end
  end
end

describe CategoriesController, type: :request do
  include_context "with MCP content rule targets"

  fab!(:root) { Fabricate(:category_with_definition, id: 113_574_001, user: admin) }
  fab!(:outside) { Fabricate(:category, id: 113_574_002, user: admin) }

  describe "#update" do
    before { sign_in(admin) }

    %i[child grandchild branch].each do |shape|
      %i[outside top_level].each do |destination|
        it "reports category errors when an admin moves a denied #{shape} to #{destination}" do
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

    it "refuses moving an existing denied grandchild after the nesting limit is lowered" do
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

    it "lets an admin move a category into a denied subtree" do
      moving = Fabricate(:category, parent_category: outside, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { parent_category_id: root.id }

      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to eq(root.id)
    end

    it "lets an admin move a category out of an allowed subtree" do
      moving = Fabricate(:category, parent_category: root, user: admin)
      protect_targets(:allow, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { parent_category_id: outside.id }

      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to eq(outside.id)
    end

    it "lets an admin move a category into an allowed subtree" do
      moving = Fabricate(:category, parent_category: outside, user: admin)
      protect_targets(:allow, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { parent_category_id: root.id }

      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to eq(root.id)
    end

    it "lets an admin move a denied category within the same denied subtree" do
      left = Fabricate(:category, parent_category: root, user: admin)
      right = Fabricate(:category, parent_category: root, user: admin)
      moving = Fabricate(:category, parent_category: left, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { parent_category_id: right.id }

      expect(response.status).to eq(200)
      expect(moving.reload.parent_category_id).to eq(right.id)
    end

    it "lets an admin move a directly denied root with its subtree intact" do
      child = Fabricate(:category, parent_category: root, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      put "/categories/#{root.id}.json", params: { parent_category_id: outside.id }

      expect(response.status).to eq(200)
      expect(root.reload.parent_category_id).to eq(outside.id)
      expect(child.reload.parent_category_id).to eq(root.id)
    end

    it "lets an admin rename a category inside a denied subtree" do
      moving = Fabricate(:category, parent_category: root, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      put "/categories/#{moving.id}.json", params: { name: "Renamed safely inside the denied tree" }

      expect(response.status).to eq(200)
      expect(moving.reload.name).to eq("Renamed safely inside the denied tree")
      expect(moving.parent_category_id).to eq(root.id)
    end

    it "lets an admin reparent and detach categories with no rules" do
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
      it "reports category errors when an admin deletes a directly #{side}-referenced category" do
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
      it "reports category errors when an admin deletes a #{shape} inside a denied subtree" do
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

    it "refuses deleting an existing denied grandchild after the nesting limit is lowered" do
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

    it "lets an admin delete a category and soft-delete its definition with no rules" do
      topic_id = root.topic_id
      post_id = root.topic.first_post.id
      expect(McpContentRule.count).to eq(0)

      delete "/categories/#{root.id}.json"

      expect(response.status).to eq(200)
      expect(Category.exists?(root.id)).to eq(false)
      expect(Topic.with_deleted.find(topic_id).deleted_at).to be_present
      expect(Post.with_deleted.find(post_id).deleted_at).to be_present
    end

    it "lets an admin delete an unreferenced category while another category is denied" do
      protect_targets(:deny, category_ids: [root.id])

      delete "/categories/#{outside.id}.json"

      expect(response.status).to eq(200)
      expect(Category.exists?(outside.id)).to eq(false)
      expect(Category.exists?(root.id)).to eq(true)
    end

    it "lets an admin delete an unreferenced descendant of an allowed category" do
      child = Fabricate(:category_with_definition, parent_category: root, user: admin)
      protect_targets(:allow, category_ids: [root.id])

      delete "/categories/#{child.id}.json"

      expect(response.status).to eq(200)
      expect(Category.exists?(child.id)).to eq(false)
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
