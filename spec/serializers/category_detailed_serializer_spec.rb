require 'rails_helper'
require_dependency 'category'

describe CategoryDetailedSerializer do

  describe "counts" do
    it "works for categories with no subcategories" do
      no_subcats = Fabricate(:category, topics_year: 10, topics_month: 5, topics_day: 2)
      json = CategoryDetailedSerializer.new(no_subcats, scope: Guardian.new, root: false).as_json
      expect(json[:topics_year]).to eq(10)
      expect(json[:topics_month]).to eq(5)
      expect(json[:topics_day]).to eq(2)
    end

    it "includes counts from subcategories" do
      parent = Fabricate(:category, topics_year: 10, topics_month: 5, topics_day: 2)
      subcategory = Fabricate(:category, parent_category_id: parent.id, topics_year: 1, topics_month: 1, topics_day: 1)
      json = CategoryDetailedSerializer.new(parent, scope: Guardian.new, root: false).as_json
      expect(json[:topics_year]).to eq(11)
      expect(json[:topics_month]).to eq(6)
      expect(json[:topics_day]).to eq(3)
    end
  end

end
