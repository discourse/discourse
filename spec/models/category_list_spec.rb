# frozen_string_literal: true

RSpec.describe CategoryList do
  before do
    # we need automatic updating here cause we are testing this
    Topic.update_featured_topics = true
  end

  fab!(:user)
  fab!(:admin)
  let(:category_list) { CategoryList.new(Guardian.new(user), include_topics: true) }

  context "when a category has a secret subcategory" do
    fab!(:category)

    fab!(:secret_subcategory) do
      cat = Fabricate(:category, parent_category: category)
      cat.set_permissions(admins: :full)
      cat.save!
      cat
    end

    let(:admin_category_list) { CategoryList.new(Guardian.new(admin), include_topics: true) }

    it "doesn't set has_children when an unpriveleged user is querying" do
      found = category_list.categories.find { |c| c.id == category.id }
      expect(found.has_children).to eq(false)
    end

    it "sets has_children when an admin is querying" do
      found = admin_category_list.categories.find { |c| c.id == category.id }
      expect(found.has_children).to eq(true)
    end
  end

  describe "security" do
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
      topic_in_public_cat = Fabricate(:topic, category: public_cat)

      private_cat = Fabricate(:category_with_definition) # private category
      topic_in_private_cat = Fabricate(:topic, category: private_cat)
      private_cat.set_permissions(admins: :full)
      private_cat.save

      secret_subcat = Fabricate(:category_with_definition, parent_category_id: public_cat.id) # private subcategory
      topic_in_secret_subcat = Fabricate(:topic, category: secret_subcat)
      secret_subcat.set_permissions(admins: :full)
      secret_subcat.save

      muted_tag = Fabricate(:tag) # muted tag
      SiteSetting.default_tags_muted = muted_tag.name
      topic_in_public_cat_2 = Fabricate(:topic, category: public_cat, tags: [muted_tag])

      muted_tag_2 = Fabricate(:tag)
      TagUser.create!(
        tag: muted_tag_2,
        user: user,
        notification_level: TagUser.notification_levels[:muted],
      )

      CategoryFeaturedTopic.feature_topics

      expect(
        CategoryList
          .new(Guardian.new(admin), include_topics: true)
          .categories
          .find { |x| x.name == public_cat.name }
          .displayable_topics
          .map(&:id),
      ).to contain_exactly(
        topic_in_public_cat.id,
        topic_in_secret_subcat.id,
        topic_in_public_cat_2.id,
      )

      expect(
        CategoryList
          .new(Guardian.new(admin), include_topics: true)
          .categories
          .find { |x| x.name == private_cat.name }
          .displayable_topics
          .map(&:id),
      ).to contain_exactly(topic_in_private_cat.id)

      expect(
        CategoryList
          .new(Guardian.new(user), include_topics: true)
          .categories
          .find { |x| x.name == public_cat.name }
          .displayable_topics
          .map(&:id),
      ).to contain_exactly(topic_in_public_cat.id, topic_in_public_cat_2.id)

      expect(
        CategoryList
          .new(Guardian.new(user), include_topics: true)
          .categories
          .find { |x| x.name == private_cat.name },
      ).to eq(nil)

      expect(
        CategoryList
          .new(Guardian.new(nil), include_topics: true)
          .categories
          .find { |x| x.name == public_cat.name }
          .displayable_topics
          .map(&:id),
      ).to contain_exactly(topic_in_public_cat.id)

      expect(
        CategoryList
          .new(Guardian.new(nil), include_topics: true)
          .categories
          .find { |x| x.name == private_cat.name },
      ).to eq(nil)
    end

    it "doesn't show muted topics" do
      cat = Fabricate(:category_with_definition) # public category
      topic = Fabricate(:topic, category: cat)

      CategoryFeaturedTopic.feature_topics

      expect(
        CategoryList
          .new(Guardian.new(user), include_topics: true)
          .categories
          .find { |x| x.name == cat.name }
          .displayable_topics
          .map(&:id),
      ).to contain_exactly(topic.id)

      TopicUser.change(user.id, topic.id, notification_level: TopicUser.notification_levels[:muted])

      expect(
        CategoryList
          .new(Guardian.new(user), include_topics: true)
          .categories
          .find { |x| x.name == cat.name }
          .displayable_topics
          .count,
      ).to eq(0)
    end
  end

  context "when mute_all_categories_by_default enabled" do
    fab!(:category)

    before { SiteSetting.mute_all_categories_by_default = true }

    it "returns correct notification level for user tracking category" do
      CategoryUser.set_notification_level_for_category(
        user,
        NotificationLevels.all[:tracking],
        category.id,
      )
      notification_level =
        category_list.categories.find { |c| c.id == category.id }.notification_level
      expect(notification_level).to eq(CategoryUser.notification_levels[:tracking])
    end

    it "returns correct notification level in default categories for anonymous" do
      SiteSetting.default_categories_watching = category.id.to_s
      notification_level =
        CategoryList
          .new(Guardian.new)
          .categories
          .find { |c| c.id == category.id }
          .notification_level
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
      let!(:pinned) do
        Fabricate(
          :topic,
          category: topic_category,
          pinned_at: 10.minutes.ago,
          bumped_at: 10.minutes.ago,
        )
      end
      let!(:dismissed_topic_user) { Fabricate(:dismissed_topic_user, topic: topic2, user: user) }

      def displayable_topics
        category_list = CategoryList.new(Guardian.new(user), include_topics: true)
        category_list.categories.find { |c| c.id == topic_category.id }.displayable_topics
      end

      it "returns pinned topic first" do
        expect(displayable_topics.map(&:id)).to eq([pinned.id, topic3.id])

        TopicUser.change(user.id, pinned.id, cleared_pinned_at: pinned.pinned_at + 10)

        expect(displayable_topics[0].dismissed).to eq(false)
        expect(displayable_topics[1].dismissed).to eq(true)

        expect(displayable_topics.map(&:id)).to eq([topic3.id, topic2.id])
      end
    end

    context "with notification level" do
      it "returns 'regular' as default notification level" do
        category = category_list.categories.find { |c| c.id == topic_category.id }
        expect(category.notification_level).to eq(NotificationLevels.all[:regular])
      end

      it "returns the users notification level" do
        CategoryUser.set_notification_level_for_category(
          user,
          NotificationLevels.all[:watching],
          topic_category.id,
        )
        category_list = CategoryList.new(Guardian.new(user))
        category = category_list.categories.find { |c| c.id == topic_category.id }

        expect(category.notification_level).to eq(NotificationLevels.all[:watching])
      end

      it "returns default notification level for anonymous users" do
        category_list = CategoryList.new(Guardian.new(nil))
        category = category_list.categories.find { |c| c.id == topic_category.id }

        expect(category.notification_level).to eq(NotificationLevels.all[:regular])
      end
    end
  end

  describe "category order" do
    def ordered_category_list(some_user)
      categories = Category.secured(Guardian.new(some_user))
      subcategories = categories.where.not(parent_category_id: nil).pluck(:id)
      CategoryList.order_categories(categories).pluck(:id) -
        subcategories.push(SiteSetting.uncategorized_category_id)
    end

    let(:category_ids_admin) { ordered_category_list(admin) }
    let(:category_ids_user) { ordered_category_list(user) }

    before do
      uncategorized = Category.find(SiteSetting.uncategorized_category_id)
      uncategorized.position = 100
      uncategorized.save
    end

    context "when fixed_category_positions is enabled" do
      before { SiteSetting.fixed_category_positions = true }

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

    context "when fixed_category_positions is disabled" do
      before { SiteSetting.fixed_category_positions = false }

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

    context "when some categories are muted" do
      let!(:cat1) { Fabricate(:category_with_definition) }
      let!(:muted_cat) { Fabricate(:category_with_definition) }
      let!(:cat3) { Fabricate(:category_with_definition) }

      before do
        CategoryUser.set_notification_level_for_category(
          user,
          NotificationLevels.all[:muted],
          muted_cat.id,
        )
      end

      it "returns muted categories at the end of the list" do
        category_list = CategoryList.new(Guardian.new user).categories.pluck(:id)

        expect(category_list).to eq(
          [SiteSetting.uncategorized_category_id, cat1.id, cat3.id, muted_cat.id],
        )
      end
    end
  end

  describe "category_list_find_categories_query modifier" do
    fab!(:cool_category) { Fabricate(:category, name: "Cool category") }
    fab!(:boring_category) { Fabricate(:category, name: "Boring category") }

    it "allows changing the query" do
      prefetched_categories = CategoryList.new(Guardian.new(user)).categories.map { |c| c[:id] }
      expect(prefetched_categories).to include(cool_category.id, boring_category.id)

      Plugin::Instance
        .new
        .register_modifier(:category_list_find_categories_query) do |query|
          query.where("categories.name LIKE 'Cool%'")
        end

      prefetched_categories = CategoryList.new(Guardian.new(user)).categories.map { |c| c[:id] }

      expect(prefetched_categories).to include(cool_category.id)
      expect(prefetched_categories).not_to include(boring_category.id)
    ensure
      DiscoursePluginRegistry.clear_modifiers!
    end
  end

  describe "with custom fields" do
    fab!(:category) { Fabricate(:category, user: admin) }

    before { category.upsert_custom_fields("bob" => "marley") }
    after { Site.reset_preloaded_category_custom_fields }

    it "can preloads custom fields" do
      Site.preloaded_category_custom_fields << "bob"

      expect(category_list.categories[-1].custom_field_preloaded?("bob")).to eq(true)
    end

    it "does not preload fields that were not set for preloading" do
      expect(category_list.categories[-1].custom_field_preloaded?("bob")).to be_falsey
    end
  end

  describe "with lazy load categories enabled" do
    fab!(:category) { Fabricate(:category, user: admin) }
    fab!(:subcategory) { Fabricate(:category, user: admin, parent_category: category) }

    before { SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}" }

    it "returns categories with subcategory_ids" do
      expect(category_list.categories.size).to eq(3)
      expect(
        category_list.categories.find { |c| c.id == category.id }.subcategory_ids,
      ).to contain_exactly(subcategory.id)
    end

    it "returns at most SUBCATEGORIES_PER_CATEGORY subcategories" do
      subcategory_2 = Fabricate(:category, user: admin, parent_category: category)

      category_list =
        stub_const(CategoryList, "SUBCATEGORIES_PER_CATEGORY", 1) do
          CategoryList.new(Guardian.new(user), include_topics: true)
        end

      expect(category_list.categories.size).to eq(3)
      uncategorized_category = Category.find(SiteSetting.uncategorized_category_id)
      expect(category_list.categories).to include(uncategorized_category)
      expect(category_list.categories).to include(category)
      expect(category_list.categories).to include(subcategory).or include(subcategory_2)
      expect(category_list.categories.map(&:parent_category_id)).to contain_exactly(
        nil,
        nil,
        category.id,
      )
    end

    context "with parent_category_id" do
      it "returns subcategories" do
        category_list = CategoryList.new(Guardian.new(user), parent_category_id: category.id)

        expect(category_list.categories.size).to eq(1)
      end
    end
  end

  describe "with many categories (more than MAX_UNOPTIMIZED_CATEGORIES)" do
    fab!(:category)
    fab!(:subcategory) { Fabricate(:category, parent_category: category) }

    it "returns at most CATEGORIES_PER_PAGE categories" do
      stub_const(CategoryList, "MAX_UNOPTIMIZED_CATEGORIES", 1) do
        category_list = CategoryList.new(Guardian.new(user))

        expect(category_list.categories).to eq(
          [Category.find(SiteSetting.uncategorized_category_id), category, subcategory],
        )
      end
    end

    context "with parent_category_id" do
      it "returns at most CATEGORIES_PER_PAGE subcategories" do
        subcategory_2 = Fabricate(:category, parent_category: category)

        stub_const(CategoryList, "MAX_UNOPTIMIZED_CATEGORIES", 1) do
          category_list = CategoryList.new(Guardian.new(user), parent_category_id: category.id)

          expect(category_list.categories).to eq([subcategory, subcategory_2])
        end
      end
    end
  end

  describe "with displayable topics" do
    fab!(:category) { Fabricate(:category, num_featured_topics: 2) }
    fab!(:topic) { Fabricate(:topic, category: category) }

    it "preloads topic associations" do
      DiscoursePluginRegistry.register_category_list_topics_preloader_association(
        :first_post,
        Plugin::Instance.new,
      )

      category = Fabricate(:category_with_definition)
      Fabricate(:topic, category: category)

      CategoryFeaturedTopic.feature_topics

      displayable_topics =
        CategoryList
          .new(Guardian.new(admin), include_topics: true)
          .categories
          .find { |x| x.id == category.id }
          .displayable_topics
      expect(displayable_topics.first.association(:first_post).loaded?).to eq(true)

      DiscoursePluginRegistry.reset_register!(:category_list_topics_preloader_associations)
    end
  end

  context "with content_localization_enabled enabled" do
    fab!(:category) { Fabricate(:category, name: "Original Name", description: "Original Desc") }
    fab!(:category_localization) { Fabricate(:category_localization, category:, locale: "ja") }

    let(:locale) { "ja" }

    before do
      SiteSetting.content_localization_enabled = true
      I18n.locale = locale
    end

    it "returns the localized name and description for the category" do
      cl = CategoryList.new(Guardian.new)
      cat = cl.categories.find { |c| c.id == category.id }
      expect(cat.name).to eq(category_localization.name)
      expect(cat.description).to eq(category_localization.description)
    end

    it "falls back to the original name and description if no localization exists" do
      other_category = Fabricate(:category, name: "Other Name", description: "Other Desc")
      cl = CategoryList.new(Guardian.new)
      cat = cl.categories.find { |c| c.id == other_category.id }
      expect(cat.name).to eq("Other Name")
      expect(cat.description).to eq("Other Desc")
    end

    it "safely returns categories when SiteSetting.fixed_category_positions is enabled" do
      SiteSetting.fixed_category_positions = true
      category_list = CategoryList.new(Guardian.new)
      expect(category_list.categories).to include(category)
    end
  end
end
