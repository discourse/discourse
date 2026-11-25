# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Tag do
  include_context "with unit five content guards"

  fab!(:tag) { Fabricate(:tag, id: 113_570_001, name: "u5-protected") }
  fab!(:other_tag) { Fabricate(:tag, id: 113_570_002, name: "u5-unreferenced") }

  describe "#destroy" do
    %i[allow deny].each do |side|
      it "[cr-u5] raises with a rule explanation when directly destroying the #{side}-referenced tag" do
        topic = Fabricate(:topic, tags: [tag])
        group = Fabricate(:tag_group, tags: [tag])
        protect_targets(side, tag_ids: [tag.id])

        aggregate_failures do
          expect { tag.destroy }.to raise_error(StandardError) { |error|
            expect_rule_explanation(error.message)
          }
          expect(Tag.exists?(tag.id)).to eq(true), "TAG DESTROY: referenced tag disappeared"
          expect(topic.reload.tags.pluck(:id)).to eq([tag.id])
          expect(group.reload.tags.pluck(:id)).to eq([tag.id])
        end
      end

      it "[cr-u5] propagates the #{side}-referenced tag destroy failure through an outer transaction" do
        topic = Fabricate(:topic, tags: [tag])
        protect_targets(side, tag_ids: [tag.id])

        aggregate_failures do
          expect do
            Tag.transaction do
              tag.destroy
              other_tag.update!(description: "The outer transaction continued")
            end
          end.to raise_error(StandardError) { |error| expect_rule_explanation(error.message) }
          expect(Tag.exists?(tag.id)).to eq(true), "OUTER TRANSACTION: referenced tag disappeared"
          expect(topic.reload.tags.pluck(:id)).to eq([tag.id])
          expect(other_tag.reload.description).to be_nil,
          "OUTER TRANSACTION: failed destroy was silently swallowed"
        end
      end

      it "[cr-u5] preserves the #{side}-referenced synonym when its canonical tag is destroyed" do
        tag.update!(target_tag: other_tag)
        protect_targets(side, tag_ids: [tag.id])

        aggregate_failures do
          expect { other_tag.destroy }.to raise_error(StandardError) { |error|
            expect_rule_explanation(error.message)
          }
          expect(Tag.where(id: [tag.id, other_tag.id]).pluck(:id)).to contain_exactly(
            tag.id,
            other_tag.id,
          )
          expect(Tag.find_by(id: tag.id)&.target_tag_id).to eq(other_tag.id)
        end
      end
    end

    it "[cr-u5] destroys tags and their synonyms inside an outer transaction with no rules" do
      tag.update!(target_tag: other_tag)
      expect(McpContentRule.count).to eq(0)

      Tag.transaction { other_tag.destroy }

      expect(Tag.where(id: [tag.id, other_tag.id])).to be_empty
    end

    it "[cr-u5] destroys an unreferenced tag while another tag is protected" do
      protect_targets(:deny, tag_ids: [tag.id])

      other_tag.destroy

      expect(Tag.where(id: [tag.id, other_tag.id]).pluck(:id)).to eq([tag.id])
    end
  end

  describe ".unused" do
    %i[allow deny].each do |side|
      it "[cr-u5] excludes a topicless #{side}-referenced tag while retaining unreferenced unused tags" do
        expect(tag.topics).to be_empty
        expect(Tag.unused.where(id: [tag.id, other_tag.id]).pluck(:id)).to contain_exactly(
          tag.id,
          other_tag.id,
        )
        protect_targets(side, tag_ids: [tag.id])

        expect(Tag.unused.where(id: [tag.id, other_tag.id]).pluck(:id)).to eq([other_tag.id]),
        "UNUSED SCOPE: referenced tag remains eligible for cleanup"
      end
    end

    it "[cr-u5] includes both topicless tags in unused with no rules" do
      expect(McpContentRule.count).to eq(0)
      expect(Tag.unused.where(id: [tag.id, other_tag.id]).pluck(:id)).to contain_exactly(
        tag.id,
        other_tag.id,
      )
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
