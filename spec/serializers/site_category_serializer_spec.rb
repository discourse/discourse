# frozen_string_literal: true

RSpec.describe SiteCategorySerializer do
  fab!(:user)
  fab!(:admin)
  fab!(:category)
  fab!(:attached_tag) { Fabricate(:tag, name: "category-allowed-tag") }
  fab!(:attached_tag_group) { Fabricate(:tag_group, name: "category-allowed-group") }

  fab!(:staff_only_required_tag_group) do
    Fabricate(:tag_group, name: "staff-only-required-group", permissions: { "staff" => 1 })
  end

  before do
    SiteSetting.tagging_enabled = true

    category.tags << attached_tag
    category.tag_groups << attached_tag_group
    category.update!(
      category_required_tag_groups: [
        CategoryRequiredTagGroup.new(tag_group: staff_only_required_tag_group, min_count: 1),
      ],
    )
  end

  after { Site.clear_cache }

  def serialize(scope)
    described_class.new(category, scope: scope, root: false).as_json
  end

  it "omits tag and tag-group names from the cached payload regardless of scope" do
    scopes = {
      "no scope" => nil,
      "anonymous guardian" => Guardian.new,
      "user guardian" => user.guardian,
      "admin guardian" => admin.guardian,
    }

    scopes.each do |label, scope|
      json = serialize(scope)
      payload_json = json.to_json

      aggregate_failures("with #{label}") do
        expect(payload_json).not_to include(attached_tag.name)
        expect(payload_json).not_to include(attached_tag_group.name)
        expect(payload_json).not_to include(staff_only_required_tag_group.name)
        expect(json[:required_tag_groups]).to eq([{ min_count: 1 }])
      end
    end
  end

  it "omits required_tag_groups when tagging is disabled" do
    SiteSetting.tagging_enabled = false

    expect(serialize(Guardian.new)).not_to have_key(:required_tag_groups)
  end
end
