# frozen_string_literal: true

require 'rails_helper'

describe SiteSerializer do
  let(:guardian) { Guardian.new }

  it "includes category custom fields only if its preloaded" do
    category = Fabricate(:category)
    category.custom_fields["enable_marketplace"] = true
    category.save_custom_fields

    data = MultiJson.dump(described_class.new(Site.new(guardian), scope: guardian, root: false))
    expect(data).not_to include("enable_marketplace")

    Site.preloaded_category_custom_fields << "enable_marketplace"

    data = MultiJson.dump(described_class.new(Site.new(guardian), scope: guardian, root: false))
    expect(data).to include("enable_marketplace")
  end
end
