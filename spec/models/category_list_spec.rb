# frozen_string_literal: true

require 'rails_helper'
require 'category_list'

describe CategoryList do
  before do
    # we need automatic updating here cause we are testing this
    Topic.update_featured_topics = true
  end

  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  let(:category_list) { CategoryList.new(Guardian.new(user), include_topics: true) }

  context "security" do

    it "properly hide secure categories" do
      cat = Fabricate(:category_with_definition)
      Fabricate(:topic, category: cat)
      cat.set_permissions(admins: :full)
      cat.save

      # uncategorized + this
      expect(CategoryList.new(Guardian.new admin).categories.count).to eq(2)
      expect(CategoryList.new(Guardian.new user).categories.count).to eq(1)
      expect(CategoryList.new(Guardian.new nil).categories.count).to eq(1)
    end

    it "doesn't show topics that you can't view" do
      public_cat = Fabricate(:category_with_definition) # public category
      Fabricate(:topic, category: public_cat)

      private_cat = Fabricate(:category_with_definition) # private category
      Fabricate(:topic, category: private_cat)
      private_cat.set_permissions(admins: :full)
      private_cat.save

      secret_subcat = Fabricate(:category_with_definition, parent_category_id: public_cat.id) # private subcategory
      Fabricate(:topic, category: secret_subcat)
      secret_subcat.set_permissions(admins: :full)
      secret_subcat.save

      CategoryFeaturedTopic.feature_topics

      expect(CategoryList.new(Guardian.new(admin), include_topics: true).categories.find { |x| x.name == public_cat.name }.displayable_topics.count).to eq(2)
      expect(CategoryList.new(Guardian.new(admin), include_topics: true).categories.find { |x| x.name == private_cat.name }.displayable_topics.count).to eq(1)

      expect(CategoryList.new(Guardian.new(user), include_topics: true).categories.find { |x| x.name == public_cat.name }.displayable_topics.count).to eq(1)
      expect(CategoryList.new(Guardian.new(user), include_topics: true).categories.find { |x| x.name == private_cat.name }).to eq(nil)

      expect(CategoryList.new(Guardian.new(nil), include_topics: true).categories.find { |x| x.name == public_cat.name }.displayable_topics.count).to eq(1)
      expect(CategoryList.new(Guardian.new(nil), include_topics: true).categories.find { |x| x.name == private_cat.name }).to eq(nil)
    end

  end

  context "when mute_all_categories_by_default enabled" do
    fab!(:category) { Fabricate(:category) }

    before do
      SiteSetting.mute_all_categories_by_default = true
    end

    it "returns correct notification level for user tracking category" do
      CategoryUser.set_notification_level_for_category(user, NotificationLevels.all[:tracking], category.id)
      notification_level = category_list.categories.find { |c| c.id == category.id }.notification_level
      expect(notification_level).to eq(CategoryUser.notification_levels[:tracking])
    end

    it "returns correct notification level in default categories for anonymous" do
      SiteSetting.default_categories_watching = category.id.to_s
      notification_level = CategoryList.new(Guardian.new).categories.find { |c| c.id == category.id }.notification_level
      expect(notification_level).to eq(CategoryUser.notification_levels[:regular])
    end
  end

  context "with a category" do

    fab!(:topic_category) { Fabricate(:category_with_definition, num_featured_topics: 2) }

    context "with a topic in a category" do
      let(:topic) { Fabricate(:topic, category: topic_category) }
      let(:category) { category_list.categories.find { |c| c.id == topic_category.id } }

      it "should return the category" do
        expect(category).to be_present
        expect(category.id).to eq(topic_category.id)
        expect(category.featured_topics.include?(topic)).to eq(true)
      end
    end

    context "with pinned topics in a category" do
      let!(:topic1) { Fabricate(:topic, category: topic_category, bumped_at: 8.minutes.ago) }
      let!(:topic2) { Fabricate(:topic, category: topic_category, bumped_at: 5.minutes.ago) }
      let!(:topic3) { Fabricate(:topic, category: topic_category, bumped_at: 2.minutes.ago) }
      let!(:pinned) { Fabricate(:topic, category: topic_category, pinned_at: 10.minutes.ago, bumped_at: 10.minutes.ago) }

      def displayable_topics
        category_list = CategoryList.new(Guardian.new(user), include_topics: true)
        category_list.categories.find { |c| c.id == topic_category.id }.displayable_topics.map(&:id)
      end

      it "returns pinned topic first" do
        expect(displayable_topics).to eq([pinned.id, topic3.id])

        TopicUser.change(user.id, pinned.id, cleared_pinned_at: pinned.pinned_at + 10)

        expect(displayable_topics).to eq([topic3.id, topic2.id])
      end
    end

    context "notification level" do
      it "returns 'regular' as default notification level" do
        category = category_list.categories.find { |c| c.id == topic_category.id }
        expect(category.notification_level).to eq(NotificationLevels.all[:regular])
      end

      it "returns the users notication level" do
        CategoryUser.set_notification_level_for_category(user, NotificationLevels.all[:watching], topic_category.id)
        category_list = CategoryList.new(Guardian.new(user))
        category = category_list.categories.find { |c| c.id == topic_category.id }

        expect(category.notification_level).to eq(NotificationLevels.all[:watching])
      end

      it "returns default notication level for anonymous users" do
        category_list = CategoryList.new(Guardian.new(nil))
        category = category_list.categories.find { |c| c.id == topic_category.id }

        expect(category.notification_level).to eq(NotificationLevels.all[:regular])
      end
    end

  end

  describe 'category order' do
    def ordered_category_list(some_user)
      categories = Category.secured(Guardian.new(some_user))
      subcategories = categories.where.not(parent_category_id: nil).pluck(:id)
      CategoryList.order_categories(categories).pluck(:id) - subcategories.push(SiteSetting.uncategorized_category_id)
    end

    let(:category_ids_admin) { ordered_category_list(admin) }
    let(:category_ids_user) { ordered_category_list(user) }

    before do
      uncategorized = Category.find(SiteSetting.uncategorized_category_id)
      uncategorized.position = 100
      uncategorized.save
    end

    context 'fixed_category_positions is enabled' do
      before do
        SiteSetting.fixed_category_positions = true
      end

      it "returns categories in specified order" do
        cat1 = Fabricate(:category_with_definition, position: 1)
        cat2 = Fabricate(:category_with_definition, position: 0)
        expect(category_ids_admin).to eq([cat2.id, cat1.id])
      end

      it "handles duplicate position values" do
        cat1 = Fabricate(:category_with_definition, position: 0)
        cat2 = Fabricate(:category_with_definition, position: 0)
        cat3 = Fabricate(:category_with_definition, position: nil)
        cat4 = Fabricate(:category_with_definition, position: 0)
        first_three = category_ids_admin[0, 3] # The order is not deterministic
        expect(first_three).to include(cat1.id)
        expect(first_three).to include(cat2.id)
        expect(first_three).to include(cat4.id)
        expect(category_ids_admin[-1]).to eq(cat3.id)
      end
    end

    context 'fixed_category_positions is disabled' do
      before do
        SiteSetting.fixed_category_positions = false
      end

      it "returns categories in order of activity" do
        cat1 = Fabricate(:category_with_definition, position: 0)
        cat2 = Fabricate(:category_with_definition, position: 1)
        cat3 = Fabricate(:category_with_definition, position: 2)
        cat4 = Fabricate(:category_with_definition, position: 3)
        cat5 = Fabricate(:category_with_definition, parent_category_id: cat2.id)

        Fabricate(:topic, category_id: cat3.id, bumped_at: 1.minutes.ago)
        Fabricate(:topic, category_id: cat5.id, bumped_at: 2.minutes.ago)
        Fabricate(:topic, category_id: cat1.id, bumped_at: 3.minutes.ago)
        Fabricate(:topic, category_id: cat2.id, bumped_at: 5.minutes.ago)

        CategoryFeaturedTopic.feature_topics

        expect(category_ids_admin).to eq([cat3.id, cat2.id, cat1.id, cat4.id])
      end

      it "returns categories in order of id when there's no activity" do
        cat1 = Fabricate(:category_with_definition, position: 2)
        cat2 = Fabricate(:category_with_definition, position: 1)
        cat3 = Fabricate(:category_with_definition, position: 0)
        expect(category_ids_admin).to eq([cat1.id, cat2.id, cat3.id])
      end

      it "shows correct order when a topic in a private category is bumped" do
        public_cat = Fabricate(:category_with_definition)
        public_cat2 = Fabricate(:category_with_definition)
        sub_cat_private = Fabricate(:category_with_definition, parent_category_id: public_cat2.id)
        sub_cat_private.set_permissions(admins: :full)
        sub_cat_private.save

        Fabricate(:topic, category: sub_cat_private, bumped_at: 1.minutes.ago)
        Fabricate(:topic, category: public_cat, bumped_at: 3.minutes.ago)
        Fabricate(:topic, category: public_cat2, bumped_at: 4.minutes.ago)

        CategoryFeaturedTopic.feature_topics

        expect(category_ids_user).to eq([public_cat.id, public_cat2.id])
        expect(category_ids_admin).to eq([public_cat2.id, public_cat.id])
      end
    end
  end

end
