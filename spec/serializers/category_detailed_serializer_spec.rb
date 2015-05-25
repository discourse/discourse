require 'spec_helper'
require_dependency 'category'

describe CategoryDetailedSerializer do

  describe "counts" do
    it "works for categories with no subcategories" do
      no_subcats = Fabricate(:category, topics_year: 10, topics_month: 5, topics_day: 2, posts_year: 13, posts_month: 7, posts_day: 3)
      json = CategoryDetailedSerializer.new(no_subcats, scope: Guardian.new, root: false).as_json
      json[:topics_year].should ==  10
      json[:topics_month].should ==  5
      json[:topics_day].should ==  2
      json[:posts_year].should ==  13
      json[:posts_month].should ==  7
      json[:posts_day].should ==  3
    end

    it "includes counts from subcategories" do
      parent = Fabricate(:category, topics_year: 10, topics_month: 5, topics_day: 2, posts_year: 13, posts_month: 7, posts_day: 3)
      subcategory = Fabricate(:category, parent_category_id: parent.id, topics_year: 1, topics_month: 1, topics_day: 1, posts_year: 1, posts_month: 1, posts_day: 1)
      json = CategoryDetailedSerializer.new(parent, scope: Guardian.new, root: false).as_json
      json[:topics_year].should ==  11
      json[:topics_month].should ==  6
      json[:topics_day].should ==  3
      json[:posts_year].should ==  14
      json[:posts_month].should ==  8
      json[:posts_day].should ==  4
    end
  end

end
