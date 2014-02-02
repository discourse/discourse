require 'spec_helper'
require 'category_list'

describe CategoryList do

  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }
  let(:category_list) { CategoryList.new(Guardian.new user) }

  context "security" do
    it "properly hide secure categories" do
      user = Fabricate(:user)

      cat = Fabricate(:category)
      Fabricate(:topic, category: cat)
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
        SiteSetting.stubs(:allow_uncategorized_topics).returns(true)
        Guardian.any_instance.expects(:can_create?).with(Category).returns(true)
        category_list.categories.should_not be_blank
      end

      it "returns empty categories with descriptions" do
        Fabricate(:category, description: 'The category description.')
        Guardian.any_instance.expects(:can_create?).with(Category).returns(false)
        category_list.categories.should_not be_blank
      end

      it 'returns the empty category and a non-empty category for those who can create them' do
        SiteSetting.stubs(:allow_uncategorized_topics).returns(true)
        Fabricate(:topic, category: Fabricate(:category))
        Guardian.any_instance.expects(:can_create?).with(Category).returns(true)
        category_list.categories.should have(3).categories
        category_list.categories.should include(topic_category)
      end

      it "doesn't return empty uncategorized category to admins if allow_uncategorized_topics is false" do
        SiteSetting.stubs(:allow_uncategorized_topics).returns(false)
        CategoryList.new(Guardian.new(user)).categories.should be_empty
        CategoryList.new(Guardian.new(admin)).categories.map(&:id).should_not include(SiteSetting.uncategorized_category_id)
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

  describe 'category order' do
    let(:category_ids) { CategoryList.new(Guardian.new(admin)).categories.map(&:id) - [SiteSetting.uncategorized_category_id] }

    before do
      uncategorized = Category.find(SiteSetting.uncategorized_category_id)
      uncategorized.position = 100
      uncategorized.save
    end

    it "returns topics in specified order" do
      cat1, cat2 = Fabricate(:category, position: 1), Fabricate(:category, position: 0)
      category_ids.should == [cat2.id, cat1.id]
    end

    it "returns default order categories" do
      cat1, cat2 = Fabricate(:category, position: nil), Fabricate(:category, position: nil)
      category_ids.should include(cat1.id)
      category_ids.should include(cat2.id)
    end

    it "default always at the end" do
      cat1, cat2, cat3 = Fabricate(:category, position: 0), Fabricate(:category, position: 2), Fabricate(:category, position: nil)
      category_ids.should == [cat1.id, cat2.id, cat3.id]
    end

    it "handles duplicate position values" do
      cat1, cat2, cat3, cat4 = Fabricate(:category, position: 0), Fabricate(:category, position: 0), Fabricate(:category, position: nil), Fabricate(:category, position: 0)
      first_three = category_ids[0,3] # The order is not deterministic
      first_three.should include(cat1.id)
      first_three.should include(cat2.id)
      first_three.should include(cat4.id)
      category_ids[-1].should == cat3.id
    end
  end

end
