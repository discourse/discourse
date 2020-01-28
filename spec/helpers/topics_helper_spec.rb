# frozen_string_literal: true

require 'rails_helper'

describe TopicsHelper do

  describe "#categories_breadcrumb" do
    let(:user) { Fabricate(:user) }

    let(:category) { Fabricate(:category_with_definition) }
    let(:subcategory) { Fabricate(:category_with_definition, parent_category_id: category.id) }
    let(:subsubcategory) { Fabricate(:category_with_definition, parent_category_id: subcategory.id) }

    it "works with sub-sub-categories" do
      SiteSetting.max_category_nesting = 3
      topic = Fabricate(:topic, category: subsubcategory)

      breadcrumbs = helper.categories_breadcrumb(topic)
      expect(breadcrumbs.length).to eq(3)
      expect(breadcrumbs[0][:name]).to eq(category.name)
      expect(breadcrumbs[1][:name]).to eq(subcategory.name)
      expect(breadcrumbs[2][:name]).to eq(subsubcategory.name)
    end
  end
end
