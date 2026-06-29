# frozen_string_literal: true

RSpec.describe Acl::User do
  subject(:user_acl) { described_class.new(flattened_acl_list) }

  fab!(:category)
  fab!(:topic)

  fab!(:other_topic, :topic)

  # The flattened permissions a single user has across multiple targets: view +
  # edit on a Category, and view on a Topic.
  let(:flattened_acl_list) do
    [
      { type: :group, id: 10, permission: "view", target_type: "Category", target_id: category.id },
      { type: :group, id: 10, permission: "edit", target_type: "Category", target_id: category.id },
      { type: :group, id: 11, permission: "view", target_type: "Topic", target_id: topic.id },
    ]
  end

  describe "#has_target_permission?" do
    it "returns true when the target record holds the permission" do
      expect(user_acl.has_target_permission?(category, "view")).to eq(true)
    end

    it "accepts a target hash as well as a record" do
      expect(
        user_acl.has_target_permission?(
          { target_type: "Category", target_id: category.id },
          "edit",
        ),
      ).to eq(true)
    end

    it "returns false when the target does not hold the permission" do
      expect(user_acl.has_target_permission?(topic, "edit")).to eq(false)
    end

    it "returns nil for a target absent from the list" do
      expect(user_acl.has_target_permission?(other_topic, "view")).to be_nil
    end
  end

  describe "#has_any_target_permission?" do
    it "returns true when the target holds any of the permissions" do
      expect(user_acl.has_any_target_permission?(category, %w[manage edit])).to eq(true)
    end

    it "returns false when the target holds none of the permissions" do
      expect(user_acl.has_any_target_permission?(topic, %w[edit manage])).to eq(false)
    end

    it "returns false for a target absent from the list" do
      expect(user_acl.has_any_target_permission?(other_topic, %w[view edit])).to eq(false)
    end
  end

  describe "#target_ids_with_permission" do
    it "returns the target ids of the given class holding the permission" do
      expect(user_acl.target_ids_with_permission(Category, "view")).to contain_exactly(category.id)
    end

    it "scopes the ids to the requested target class" do
      expect(user_acl.target_ids_with_permission(Topic, "view")).to contain_exactly(topic.id)
    end

    it "returns an empty array when no target of that class holds the permission" do
      expect(user_acl.target_ids_with_permission(Category, "manage")).to eq([])
    end

    it "returns an empty array when the class has no entry for the permission" do
      expect(user_acl.target_ids_with_permission(Topic, "edit")).to eq([])
    end
  end

  describe "#target_ids_with_any_permissions" do
    it "returns the unique target ids across all the permissions" do
      expect(user_acl.target_ids_with_any_permissions(Category, %w[view edit])).to contain_exactly(
        category.id,
      )
    end

    it "scopes the combined ids to the requested target class" do
      expect(user_acl.target_ids_with_any_permissions(Topic, %w[view edit])).to contain_exactly(
        topic.id,
      )
    end
  end
end
