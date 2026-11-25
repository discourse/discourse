# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe Category do
  include_context "with unit five content guards"

  fab!(:root) { Fabricate(:category_with_definition, id: 113_575_001, user: admin) }

  describe "#destroy" do
    %i[allow deny].each do |side|
      it "[cr-u5] returns model errors when directly destroying the #{side}-referenced category" do
        topic_id = root.topic_id
        timer = Fabricate(:topic_timer, category: root)
        protect_targets(side, category_ids: [root.id])

        result = root.destroy

        aggregate_failures do
          expect(result).to eq(false), "CATEGORY MODEL DELETE: referenced category destroyed"
          expect_rule_explanation(root.errors.full_messages.join(" "))
          expect(Category.exists?(root.id)).to eq(true)
          expect(TopicTimer.exists?(timer.id)).to eq(true)
          expect(Topic.with_deleted.find(topic_id).deleted_at).to be_nil
        end
      end
    end

    it "[cr-u5] preserves a denied grandchild and its definition inside an outer destroy transaction" do
      child = Fabricate(:category, parent_category: root, user: admin)
      grandchild = Fabricate(:category_with_definition, parent_category: child, user: admin)
      topic_id = grandchild.topic_id
      timer = Fabricate(:topic_timer, category: grandchild)
      protect_targets(:deny, category_ids: [root.id])
      result = nil

      Category.transaction { result = grandchild.destroy }

      aggregate_failures do
        expect(result).to eq(false), "CATEGORY OUTER DELETE: denied grandchild destroyed"
        expect_rule_explanation(grandchild.errors.full_messages.join(" "))
        expect(Category.exists?(grandchild.id)).to eq(true)
        expect(TopicTimer.exists?(timer.id)).to eq(true)
        expect(Topic.with_deleted.find(topic_id).deleted_at).to be_nil
      end
    end

    it "[cr-u5] destroys a category and its dependent timer inside an outer transaction with no rules" do
      topic_id = root.topic_id
      timer = Fabricate(:topic_timer, category: root)
      expect(McpContentRule.count).to eq(0)

      Category.transaction { root.destroy }

      expect(Category.exists?(root.id)).to eq(false)
      expect(TopicTimer.exists?(timer.id)).to eq(false)
      expect(Topic.with_deleted.find(topic_id).deleted_at).to be_present
    end
  end

  describe "#update" do
    it "[cr-u5] returns model errors when directly detaching a denied grandchild" do
      child = Fabricate(:category, parent_category: root, user: admin)
      grandchild = Fabricate(:category, parent_category: child, user: admin)
      protect_targets(:deny, category_ids: [root.id])

      result = grandchild.update(parent_category_id: nil)

      aggregate_failures do
        expect(result).to eq(false), "CATEGORY MODEL MOVE: denied grandchild escaped"
        expect_rule_explanation(grandchild.errors.full_messages.join(" "))
        expect(grandchild.reload.parent_category_id).to eq(child.id)
      end
    end
  end
end

describe CategoryUpdater, ".update" do
  include_context "with unit five content guards"

  it "[cr-u5] returns category errors from the real updater when moving a denied branch outside" do
    root = Fabricate(:category, user: admin)
    branch = Fabricate(:category, parent_category: root, user: admin)
    leaf = Fabricate(:category, parent_category: branch, user: admin)
    outside = Fabricate(:category, user: admin)
    protect_targets(:deny, category_ids: [root.id])

    result = CategoryUpdater.update(admin.guardian, branch, parent_category_id: outside.id)

    aggregate_failures do
      expect(result).to eq(false), "CATEGORY UPDATER: denied branch escaped"
      expect_rule_explanation(branch.errors.full_messages.join(" "))
      expect(branch.reload.parent_category_id).to eq(root.id)
      expect(leaf.reload.parent_category_id).to eq(branch.id)
    end
  end

  it "[cr-u5] lets the updater move a branch with no rules" do
    root = Fabricate(:category, user: admin)
    branch = Fabricate(:category, parent_category: root, user: admin)
    outside = Fabricate(:category, user: admin)
    expect(McpContentRule.count).to eq(0)

    expect(CategoryUpdater.update(admin.guardian, branch, parent_category_id: outside.id)).to eq(
      true,
    )
    expect(branch.reload.parent_category_id).to eq(outside.id)
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
