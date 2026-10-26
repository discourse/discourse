# frozen_string_literal: true

RSpec.describe TopicsController, type: :request do
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:restricted_group, :tag_group)
  fab!(:restricted_tag, :tag)
  fab!(:ordinary_tag, :tag)
  fab!(:first_post) { Fabricate(:post, topic: Fabricate(:topic, category:)) }
  fab!(:second_post) { Fabricate(:post, topic: Fabricate(:topic, category:)) }

  describe "#bulk" do
    before do
      SiteSetting.tagging_enabled = true
      TagGroupMembership.create!(tag: restricted_tag, tag_group: restricted_group)
      CategoryTagGroup.create!(category:, tag_group: restricted_group)
      sign_in(admin)
    end

    it "searches and adds global and restricted tags when the category permits both" do
      category.update!(allow_global_tags: true)

      get "/tags/filter/search.json", params: { categoryId: category.id, filterForInput: true }

      expect(response.status).to eq(200)
      expect(response.parsed_body["results"].map { |tag| tag["id"] }).to contain_exactly(
        restricted_tag.id,
        ordinary_tag.id,
      )

      put "/topics/bulk.json",
          params: {
            topic_ids: [first_post.topic_id, second_post.topic_id],
            operation: {
              type: "manage_tags",
              add_tag_ids: [restricted_tag.id, ordinary_tag.id],
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(
        first_post.topic_id,
        second_post.topic_id,
      )
      expect(first_post.topic.reload.tags).to contain_exactly(restricted_tag, ordinary_tag)
      expect(second_post.topic.reload.tags).to contain_exactly(restricted_tag, ordinary_tag)
    end

    it "removes and replaces restricted tags without retaining either old tag" do
      replacement_source = Fabricate(:tag)
      TagGroupMembership.create!(tag: replacement_source, tag_group: restricted_group)
      category.update!(allow_global_tags: true)
      first_post.topic.update!(tags: [restricted_tag, replacement_source])

      put "/topics/bulk.json",
          params: {
            topic_ids: [first_post.topic_id, second_post.topic_id],
            operation: {
              type: "manage_tags",
              remove_tag_ids: [restricted_tag.id],
              replace_tags: [{ from_tag_id: replacement_source.id, to_tag_id: ordinary_tag.id }],
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(first_post.topic_id)
      expect(first_post.topic.reload.tags).to contain_exactly(ordinary_tag)
      expect(second_post.topic.reload.tags).to be_empty
    end

    it "adds a restricted tag across two categories when both permit it" do
      second_post.topic.update!(category: other_category)
      CategoryTagGroup.create!(category: other_category, tag_group: restricted_group)

      put "/topics/bulk.json",
          params: {
            topic_ids: [first_post.topic_id, second_post.topic_id],
            operation: {
              type: "manage_tags",
              add_tag_ids: [restricted_tag.id],
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(
        first_post.topic_id,
        second_post.topic_id,
      )
      expect(first_post.topic.reload.tags).to contain_exactly(restricted_tag)
      expect(second_post.topic.reload.tags).to contain_exactly(restricted_tag)
    end
  end
end
