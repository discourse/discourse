require 'spec_helper'
require 'category_list'

describe CategoryList do

  let(:user) { Fabricate(:user) }
  let(:category_list) { CategoryList.new(Guardian.new user) }

  context "security" do
    it "properly hide secure categories" do
      admin = Fabricate(:admin)
      user = Fabricate(:user)

      cat = Fabricate(:category)
      topic = Fabricate(:topic, category: cat)
      cat.set_permissions(:admins => :full)
      cat.save

      # uncategorized + this
      CategoryList.new(Guardian.new admin).categories.count.should == 2

      CategoryList.new(Guardian.new user).categories.count.should == 0
      CategoryList.new(Guardian.new nil).categories.count.should == 0
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
        category_list.categories.should_not be_blank
      end

      it "returns empty categories with descriptions" do
        Fabricate(:category, description: 'The category description.')
        Guardian.any_instance.expects(:can_create?).with(Category).returns(false)
        category_list.categories.should_not be_blank
      end

      it 'returns the empty category and a non-empty category for those who can create them' do
        category_with_topics = Fabricate(:topic, category: Fabricate(:category))
        Guardian.any_instance.expects(:can_create?).with(Category).returns(true)
        category_list.categories.should have(3).categories
        category_list.categories.should include(topic_category)
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
