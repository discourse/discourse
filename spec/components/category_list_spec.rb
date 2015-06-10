require 'spec_helper'
require 'category_list'

describe CategoryList do

  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }
  let(:category_list) { CategoryList.new(Guardian.new user) }

  context "security" do
    it "properly hide secure categories" do
      cat = Fabricate(:category)
      Fabricate(:topic, category: cat)
      cat.set_permissions(:admins => :full)
      cat.save

      # uncategorized + this
      expect(CategoryList.new(Guardian.new admin).categories.count).to eq(2)
      expect(CategoryList.new(Guardian.new user).categories.count).to eq(0)
      expect(CategoryList.new(Guardian.new nil).categories.count).to eq(0)
    end

    it "doesn't show topics that you can't view" do
      public_cat = Fabricate(:category) # public category
      Fabricate(:topic, category: public_cat)

      private_cat = Fabricate(:category) # private category
      Fabricate(:topic, category: private_cat)
      private_cat.set_permissions(admins: :full)
      private_cat.save

      secret_subcat = Fabricate(:category, parent_category_id: public_cat.id) # private subcategory
      Fabricate(:topic, category: secret_subcat)
      secret_subcat.set_permissions(admins: :full)
      secret_subcat.save

      CategoryFeaturedTopic.feature_topics

      expect(CategoryList.new(Guardian.new(admin)).categories.find { |x| x.name == public_cat.name }.displayable_topics.count).to eq(2)
      expect(CategoryList.new(Guardian.new(admin)).categories.find { |x| x.name == private_cat.name }.displayable_topics.count).to eq(1)

      expect(CategoryList.new(Guardian.new(user)).categories.find { |x| x.name == public_cat.name }.displayable_topics.count).to eq(1)
      expect(CategoryList.new(Guardian.new(user)).categories.find { |x| x.name == private_cat.name }).to eq(nil)

      expect(CategoryList.new(Guardian.new(nil)).categories.find { |x| x.name == public_cat.name }.displayable_topics.count).to eq(1)
      expect(CategoryList.new(Guardian.new(nil)).categories.find { |x| x.name == private_cat.name }).to eq(nil)
    end
  end

  context "with a category" do

    let!(:topic_category) { Fabricate(:category) }

    context "without a featured topic" do

      it "should not return empty categories" do
        expect(category_list.categories).to be_blank
      end

      it "returns empty categories for those who can create them" do
        SiteSetting.stubs(:allow_uncategorized_topics).returns(true)
        Guardian.any_instance.expects(:can_create?).with(Category).returns(true)
        expect(category_list.categories).not_to be_blank
      end

      it "returns empty categories with descriptions" do
        Fabricate(:category, description: 'The category description.')
        Guardian.any_instance.expects(:can_create?).with(Category).returns(false)
        expect(category_list.categories).not_to be_blank
      end

      it 'returns the empty category and a non-empty category for those who can create them' do
        SiteSetting.stubs(:allow_uncategorized_topics).returns(true)
        Fabricate(:topic, category: Fabricate(:category))
        Guardian.any_instance.expects(:can_create?).with(Category).returns(true)
        expect(category_list.categories.size).to eq(3)
        expect(category_list.categories).to include(topic_category)
      end

      it "doesn't return empty uncategorized category to admins if allow_uncategorized_topics is false" do
        SiteSetting.stubs(:allow_uncategorized_topics).returns(false)
        expect(CategoryList.new(Guardian.new(user)).categories).to be_empty
        expect(CategoryList.new(Guardian.new(admin)).categories.map(&:id)).not_to include(SiteSetting.uncategorized_category_id)
      end

    end

    context "with a topic in a category" do
      let!(:topic) { Fabricate(:topic, category: topic_category) }
      let(:category) { category_list.categories.first }

      it "should return the category" do
        expect(category).to be_present
      end

      it "returns the correct category" do
        expect(category.id).to eq(topic_category.id)
      end

      it "should contain our topic" do
        expect(category.featured_topics.include?(topic)).to eq(true)
      end
    end

    context "with pinned topics in a category" do
      let!(:topic1) { Fabricate(:topic, category: topic_category, bumped_at: 8.minutes.ago) }
      let!(:topic2) { Fabricate(:topic, category: topic_category, bumped_at: 5.minutes.ago) }
      let!(:topic3) { Fabricate(:topic, category: topic_category, bumped_at: 2.minutes.ago) }
      let!(:pinned) { Fabricate(:topic, category: topic_category, pinned_at: 10.minutes.ago, bumped_at: 10.minutes.ago) }
      let(:category) { category_list.categories.first }

      before do
        SiteSetting.stubs(:category_featured_topics).returns(2)
      end

      it "returns pinned topic first" do
        expect(category.displayable_topics.map(&:id)).to eq([pinned.id, topic3.id])
      end

      it "returns topics in bumped_at order if pinned was unpinned" do
        PinnedCheck.stubs(:unpinned?).returns(true)
        expect(category.displayable_topics.map(&:id)).to eq([topic3.id, topic2.id])
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

    context 'fixed_category_positions is enabled' do
      before do
        SiteSetting.stubs(:fixed_category_positions).returns(true)
      end

      it "returns categories in specified order" do
        cat1, cat2 = Fabricate(:category, position: 1), Fabricate(:category, position: 0)
        expect(category_ids).to eq([cat2.id, cat1.id])
      end

      it "handles duplicate position values" do
        cat1, cat2, cat3, cat4 = Fabricate(:category, position: 0), Fabricate(:category, position: 0), Fabricate(:category, position: nil), Fabricate(:category, position: 0)
        first_three = category_ids[0,3] # The order is not deterministic
        expect(first_three).to include(cat1.id)
        expect(first_three).to include(cat2.id)
        expect(first_three).to include(cat4.id)
        expect(category_ids[-1]).to eq(cat3.id)
      end
    end

    context 'fixed_category_positions is disabled' do
      before do
        SiteSetting.stubs(:fixed_category_positions).returns(false)
      end

      it "returns categories in order of activity" do
        cat1 = Fabricate(:category, position: 0, posts_week: 1, posts_month: 1, posts_year: 1)
        cat2 = Fabricate(:category, position: 1, posts_week: 2, posts_month: 1, posts_year: 1)
        expect(category_ids).to eq([cat2.id, cat1.id])
      end

      it "returns categories in order of id when there's no activity" do
        cat1, cat2 = Fabricate(:category, position: 1), Fabricate(:category, position: 0)
        expect(category_ids).to eq([cat1.id, cat2.id])
      end
    end
  end

end
