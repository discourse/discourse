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

      it "has the right category" do
        category.should be_present
        category.name.should == SiteSetting.uncategorized_name
        category.slug.should == SiteSetting.uncategorized_name
        category.topics_week.should == 1
        category.featured_topics.should == [topic]
      end

    end

  end

  context "security" do
    it "properly hide secure categories" do
      admin = Fabricate(:admin)
      user = Fabricate(:user)

      cat = Fabricate(:category)
      topic = Fabricate(:topic, category: cat)
      cat.deny(:all)
      cat.allow(Group[:admins])
      cat.save

      CategoryList.new(admin).categories.count.should == 1
      CategoryList.new(user).categories.count.should == 0
      CategoryList.new(nil).categories.count.should == 0
    end
  end

  context "with a category" do

    let!(:topic_category) { Fabricate(:category) }

    context "without a featured topic" do

      it "should not return empty categories" do
        category_list.categories.should be_blank
      end

      it "returns empty the empty for those who can create them" do
        Guardian.any_instance.expects(:can_create?).with(Category).returns(true)
        category_list.categories.should_not be_blank
      end

      it 'returns the empty category and a non-empty category for those who can create them' do
        category_with_topics = Fabricate(:topic, category: Fabricate(:category))
        Guardian.any_instance.expects(:can_create?).with(Category).returns(true)
        category_list.categories.should have(2).categories
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
