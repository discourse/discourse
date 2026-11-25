# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe TagsController, type: :request do
  include_context "with unit five content guards"

  fab!(:tag) { Fabricate(:tag, id: 113_573_001, name: "u5-request-protected") }
  fab!(:other_tag) { Fabricate(:tag, id: 113_573_002, name: "u5-request-other") }

  describe "#destroy" do
    before { sign_in(admin) }

    %i[allow deny].each do |side|
      it "[cr-u5] reports a content rule error to an admin deleting the #{side}-referenced tag" do
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

    it "[cr-u5] lets an admin delete a tag with no rules" do
      expect(McpContentRule.count).to eq(0)

      delete "/tag/#{tag.name}.json"

      expect(response.status).to eq(200)
      expect(Tag.exists?(tag.id)).to eq(false)
    end

    it "[cr-u5] lets an admin delete an unreferenced tag while another tag is protected" do
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
        it "[cr-u5] reports a failed tag for an admin converting the #{side}-referenced synonym by #{input}" do
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

    it "[cr-u5] lets an admin convert a tag to a synonym with no rules" do
      expect(McpContentRule.count).to eq(0)

      post "/tag/#{other_tag.name}/synonyms.json", params: { tags: [{ id: tag.id }] }

      expect(response.status).to eq(200)
      expect(response.parsed_body["failed"]).to be_nil
      expect(tag.reload.target_tag_id).to eq(other_tag.id)
    end

    it "[cr-u5] lets an admin add an unreferenced synonym to a protected target" do
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
      it "[cr-u5] keeps a topicless #{side}-referenced tag while admin cleanup deletes an unused peer" do
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

    it "[cr-u5] lets admin cleanup delete both unused tags with no rules" do
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
      it "[cr-u5] omits the #{side}-referenced tag from the admin unused-tag preview" do
        protect_targets(side, tag_ids: [tag.id])

        get "/tags/unused.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.fetch("tags") & [tag.name, other_tag.name]).to eq(
          [other_tag.name],
        ),
        "UNUSED PREVIEW: referenced tag is offered for deletion"
      end
    end

    it "[cr-u5] previews both unused tags with no rules" do
      expect(McpContentRule.count).to eq(0)
      names = [tag.name, other_tag.name]

      get "/tags/unused.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("tags") & names).to contain_exactly(*names)
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
