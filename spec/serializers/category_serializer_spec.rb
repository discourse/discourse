# frozen_string_literal: true

require 'rails_helper'

describe CategorySerializer do
  fab!(:group) { Fabricate(:group) }
  fab!(:category) { Fabricate(:category, reviewable_by_group_id: group.id) }

  it "includes the reviewable by group name if enabled" do
    SiteSetting.enable_category_group_review = true
    json = described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json[:reviewable_by_group_name]).to eq(group.name)
  end

  it "doesn't include the reviewable by group name if disabled" do
    SiteSetting.enable_category_group_review = false
    json = described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json[:reviewable_by_group_name]).to be_blank
  end

  it "includes custom fields" do
    json = described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json[:custom_fields]).to be_empty

    category.custom_fields["enable_marketplace"] = true
    category.save_custom_fields

    json = described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json[:custom_fields]).to be_present
  end
end
