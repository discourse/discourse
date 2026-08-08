# frozen_string_literal: true

RSpec.describe SiteCategorySerializer do
  subject(:json) { described_class.new(category, scope: scope, root: false).as_json }

  fab!(:user)
  fab!(:admin)
  fab!(:category)

  describe "#required_tag_groups" do
    fab!(:required_tag_group) { Fabricate(:tag_group, name: "category-required-group") }

    fab!(:category_required_tag_group) do
      CategoryRequiredTagGroup.create!(
        category: category,
        tag_group: required_tag_group,
        min_count: 1,
      )
    end

    after { Site.clear_cache }

    context "for a non-editor" do
      let(:scope) { user.guardian }

      it "omits the tag-group name from each entry" do
        expect(json[:required_tag_groups]).to eq([{ min_count: 1 }])
      end
    end

    context "for an editor" do
      let(:scope) { admin.guardian }

      it "includes the tag-group name in each entry" do
        expect(json[:required_tag_groups]).to eq([{ name: required_tag_group.name, min_count: 1 }])
      end
    end

    context "when tagging is disabled" do
      let(:scope) { admin.guardian }

      before { SiteSetting.tagging_enabled = false }

      it "is not included" do
        expect(json).not_to have_key(:required_tag_groups)
      end
    end
  end
end
