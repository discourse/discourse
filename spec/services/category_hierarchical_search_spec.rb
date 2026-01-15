# frozen_string_literal: true

RSpec.describe CategoryHierarchicalSearch do
  before_all { SiteSetting.max_category_nesting = 3 }

  fab!(:user)
  fab!(:parent_2) { Fabricate(:category, name: "Parent 2") }
  fab!(:parent_1) { Fabricate(:category, name: "Parent 1") }

  fab!(:parent_1_sub_category_1) do
    Fabricate(:category, name: "Parent 1 Sub Category 1", parent_category: parent_1)
  end

  fab!(:parent_1_sub_category_2) do
    Fabricate(:category, name: "Parent 1 Sub Category 2", parent_category: parent_1)
  end

  fab!(:parent_2_sub_category_1) do
    Fabricate(:category, name: "Parent 2 Sub Category 1", parent_category: parent_2)
  end

  fab!(:parent_2_sub_category_2) do
    Fabricate(:category, name: "Parent 2 Sub Category 2", parent_category: parent_2)
  end

  fab!(:parent_1_sub_category_1_sub_sub_category_1) do
    Fabricate(
      :category,
      name: "Parent 1 Sub Category 1 Sub Sub Category 1 Match",
      parent_category: parent_1_sub_category_1,
    )
  end

  fab!(:parent_1_sub_category_1_sub_sub_category_2) do
    Fabricate(
      :category,
      name: "Parent 1 Sub Category 1 Sub Sub Category 2",
      parent_category: parent_1_sub_category_1,
    )
  end

  fab!(:parent_1_sub_category_2_sub_sub_category_1) do
    Fabricate(
      :category,
      name: "Parent 1 Sub Category 2 Sub Sub Category 1",
      parent_category: parent_1_sub_category_2,
    )
  end

  fab!(:parent_1_sub_category_2_sub_sub_category_2) do
    Fabricate(
      :category,
      name: "Parent 1 Sub Category 2 Sub Sub Category 2",
      parent_category: parent_1_sub_category_2,
    )
  end

  fab!(:parent_2_sub_category_1_sub_sub_category_1) do
    Fabricate(
      :category,
      name: "Parent 2 Sub Category 1 Sub Sub Category 1",
      parent_category: parent_2_sub_category_1,
    )
  end

  fab!(:parent_2_sub_category_1_sub_sub_category_2) do
    Fabricate(
      :category,
      name: "Parent 2 Sub Category 1 Sub Sub Category 2",
      parent_category: parent_2_sub_category_1,
    )
  end

  fab!(:parent_2_sub_category_2_sub_sub_category_1) do
    Fabricate(
      :category,
      name: "Parent 2 Sub Category 2 Sub Sub Category 1",
      parent_category: parent_2_sub_category_2,
    )
  end

  fab!(:parent_2_sub_category_2_sub_sub_category_2) do
    Fabricate(
      :category,
      name: "Parent 2 Sub Category 2 Sub Sub Category 2 MATCH",
      parent_category: parent_2_sub_category_2,
    )
  end

  it "returns categories with their ancestors that match the terms param in a hierarchical order" do
    context = described_class.call(guardian: Guardian.new, params: { term: "match" })

    expect(context).to be_success

    expect(context.categories.map(&:name)).to eq(
      [
        parent_1.name,
        parent_1_sub_category_1.name,
        parent_1_sub_category_1_sub_sub_category_1.name,
        parent_2.name,
        parent_2_sub_category_2.name,
        parent_2_sub_category_2_sub_sub_category_2.name,
      ],
    )
  end

  it "returns categories with their ancestors that have ids which are included in the only_ids param in a hierarchical order" do
    context =
      described_class.call(
        guardian: Guardian.new,
        params: {
          only_ids: [
            parent_1_sub_category_1_sub_sub_category_1.id,
            parent_2_sub_category_2_sub_sub_category_2.id,
          ],
        },
      )

    expect(context).to be_success

    expect(context.categories.map(&:name)).to eq(
      [
        parent_1.name,
        parent_1_sub_category_1.name,
        parent_1_sub_category_1_sub_sub_category_1.name,
        parent_2.name,
        parent_2_sub_category_2.name,
        parent_2_sub_category_2_sub_sub_category_2.name,
      ],
    )
  end

  it "returns categories with their ancestors that have ids which is not included in the except_ids param in a hierarchical order" do
    context =
      described_class.call(
        guardian: Guardian.new,
        params: {
          except_ids: [
            parent_1_sub_category_2_sub_sub_category_1.id,
            parent_1_sub_category_2_sub_sub_category_2.id,
            parent_2_sub_category_1_sub_sub_category_1.id,
            parent_2_sub_category_1_sub_sub_category_2.id,
          ],
        },
      )

    expect(context).to be_success

    expect(context.categories.map(&:name)).to eq(
      [
        parent_1.name,
        parent_1_sub_category_1.name,
        parent_1_sub_category_1_sub_sub_category_1.name,
        parent_1_sub_category_1_sub_sub_category_2.name,
        parent_1_sub_category_2.name,
        parent_2.name,
        parent_2_sub_category_1.name,
        parent_2_sub_category_2.name,
        parent_2_sub_category_2_sub_sub_category_1.name,
        parent_2_sub_category_2_sub_sub_category_2.name,
      ],
    )
  end

  it "excludes categories that the guardian cannot see" do
    restricted_group = Fabricate(:group)
    restricted_parent_category = Fabricate(:category, name: "Restricted Parent")
    restricted_parent_category.set_permissions(restricted_group => :full)
    restricted_parent_category.save!

    context = described_class.call(guardian: Guardian.new, params: { term: "restricted" })

    expect(context).to be_success
    expect(context.categories).to be_empty
  end

  it "applies a limit and offset" do
    context = described_class.call(guardian: Guardian.new, params: { limit: 2 })

    expect(context.categories.map(&:name)).to eq([parent_1.name, parent_1_sub_category_1.name])

    context = described_class.call(guardian: Guardian.new, params: { limit: 2, offset: 2 })

    expect(context.categories.map(&:name)).to eq(
      [
        parent_1_sub_category_1_sub_sub_category_1.name,
        parent_1_sub_category_1_sub_sub_category_2.name,
      ],
    )
  end
end
