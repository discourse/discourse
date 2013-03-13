require 'spec_helper'
require 'category_list'

describe CategoryList do

  let(:user) { Fabricate(:user) }
  let(:category_list) { CategoryList.new(user) }

  context "with no categories" do

    it "has no categories" do
      category_list.categories.should be_blank
    end

    context "with an uncateorized topic" do
      let!(:topic) { Fabricate(:topic)}
      let(:category) { category_list.categories.first }

      it "has a category" do
        category.should be_present
      end

      it "has the uncategorized label" do
        category.name.should == SiteSetting.uncategorized_name
      end

      it "has the uncategorized slug" do
        category.slug.should == SiteSetting.uncategorized_name
      end

      it "has one topic this week" do
        category.topics_week.should == 1
      end

      it "contains the topic in featured_topics" do
        category.featured_topics.should == [topic]
      end

    end

  end

  context "with a category" do

    let!(:topic_category) { Fabricate(:category) }

    context "without a featured topic" do

      it "should not return empty categories" do
        category_list.categories.should be_blank
      end

      it "returns empty categories for those who can create them" do
        Guardian.any_instance.expects(:can_create?).with(Category).returns(true)
        category_list.categories.should be_present
      end


    end


    context "with a topic in a category" do
      let!(:topic) { Fabricate(:topic, category: topic_category)}
      let(:category) { category_list.categories.first }

      it "should return the category" do
        category.should be_present
      end

      it "returns the correct category" do
        category.id.should == topic_category.id
      end

      it "should contain our topic" do
        category.featured_topics.include?(topic).should be_true
      end
    end


  end


end
