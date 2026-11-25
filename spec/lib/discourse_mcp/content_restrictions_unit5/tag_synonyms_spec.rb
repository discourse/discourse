# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseTagging, ".add_or_create_synonyms" do
  include_context "with unit five content guards"

  fab!(:tag) { Fabricate(:tag, id: 113_571_001, name: "u5-synonym-source") }
  fab!(:target) { Fabricate(:tag, id: 113_571_002, name: "u5-synonym-target") }

  %i[allow deny].each do |side|
    %i[id name].each do |input|
      it "[cr-u5] refuses conversion of the #{side}-referenced tag to a synonym by #{input}" do
        topic = Fabricate(:topic, tags: [tag])
        protect_targets(side, tag_ids: [tag.id])
        arguments =
          input == :id ? { synonym_tag_ids: [tag.id] } : { new_synonym_names: [tag.name.upcase] }

        result = DiscourseTagging.add_or_create_synonyms(target, **arguments)

        aggregate_failures do
          expect(result).to be_a(Hash), "SYNONYM SERVICE: referenced tag conversion succeeded"
          expect_rule_explanation(result[tag.name].to_s) if result.is_a?(Hash)
          expect(tag.reload.target_tag_id).to be_nil
          expect(topic.reload.tags.pluck(:id)).to eq([tag.id])
        end
      end
    end
  end

  it "[cr-u5] converts a tag and transfers its topic tags with no rules" do
    topic = Fabricate(:topic, tags: [tag])
    expect(McpContentRule.count).to eq(0)

    expect(DiscourseTagging.add_or_create_synonyms(target, synonym_tag_ids: [tag.id])).to eq(true)
    expect(tag.reload.target_tag_id).to eq(target.id)
    expect(topic.reload.tags.pluck(:id)).to eq([target.id])
  end

  it "[cr-u5] permits an unreferenced tag to become a synonym of a referenced target" do
    protect_targets(:deny, tag_ids: [target.id])

    expect(DiscourseTagging.add_or_create_synonyms(target, new_synonym_names: [tag.name])).to eq(
      true,
    )
    expect(tag.reload.target_tag_id).to eq(target.id)
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
