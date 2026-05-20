# frozen_string_literal: true

RSpec.describe SiteCategorySerializer do
  fab!(:user)
  fab!(:admin)
  fab!(:category)
  fab!(:tag)
  fab!(:public_tag_group, :tag_group)
  fab!(:hidden_tag) { Fabricate(:tag, name: "secret") }

  fab!(:staff_tag_group) do
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
  end

  before do
    SiteSetting.tagging_enabled = true

    category.tags << tag
    category.tag_groups << public_tag_group
    category.update!(
      category_required_tag_groups: [
        CategoryRequiredTagGroup.new(tag_group: staff_tag_group, min_count: 1),
      ],
    )
  end

  after { Site.clear_cache }

  it "omits name-bearing tag fields and limits required_tag_groups to min_count for every scope" do
    [nil, Guardian.new, Guardian.new(user), Guardian.new(admin)].each do |scope|
      json = described_class.new(category, scope: scope, root: false).as_json

      aggregate_failures "scope: #{scope.inspect}" do
        expect(json).not_to have_key(:allowed_tags)
        expect(json).not_to have_key(:allowed_tag_groups)
        expect(json[:required_tag_groups]).to eq([{ min_count: 1 }])
      end
    end
  end

  it "omits required_tag_groups when tagging is disabled" do
    SiteSetting.tagging_enabled = false

    json = described_class.new(category, scope: Guardian.new, root: false).as_json

    expect(json).not_to have_key(:required_tag_groups)
  end
end
