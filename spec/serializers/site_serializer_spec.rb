# frozen_string_literal: true

require 'rails_helper'

describe SiteSerializer do
  let(:guardian) { Guardian.new }
  let(:category) { Fabricate(:category) }

  it "includes category custom fields only if its preloaded" do
    category.custom_fields["enable_marketplace"] = true
    category.save_custom_fields

    data = MultiJson.dump(described_class.new(Site.new(guardian), scope: guardian, root: false))
    expect(data).not_to include("enable_marketplace")

    Site.preloaded_category_custom_fields << "enable_marketplace"

    data = MultiJson.dump(described_class.new(Site.new(guardian), scope: guardian, root: false))
    expect(data).to include("enable_marketplace")
  end

  it "returns correct notification level for categories" do
    SiteSetting.mute_all_categories_by_default = true
    SiteSetting.default_categories_regular = category.id.to_s

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    categories = serialized[:categories]
    expect(categories[0][:notification_level]).to eq(0)
    expect(categories[-1][:notification_level]).to eq(1)
  end
end
