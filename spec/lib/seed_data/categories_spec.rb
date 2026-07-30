# frozen_string_literal: true

require "seed_data/categories"

RSpec.describe SeedData::Categories do
  subject(:seeder) { SeedData::Categories.with_default_locale }

  describe "#create" do
    let(:full_permissions_for_staff) do
      {
        group_id: Group::AUTO_GROUPS[:staff],
        permission_type: CategoryGroup.permission_types[:full],
      }
    end
    let(:full_permissions_for_trust_level_2) do
      {
        group_id: Group::AUTO_GROUPS[:trust_level_2],
        permission_type: CategoryGroup.permission_types[:full],
      }
    end

    it "creates a missing category" do
      expect { seeder.create(site_setting_names: ["staff_category_id"]) }.to change {
        Category.count
      }.by(1).and change { Topic.count }.by(1)

      category = Category.last
      expect(category.name).to eq(I18n.t("staff_category_name"))
      expect(category.topic_id).to be_present
      expect(category.user_id).to eq(Discourse::SYSTEM_USER_ID)
      expect(category.category_groups.count).to eq(1)
      expect(category.category_groups.first).to have_attributes(full_permissions_for_staff)
      expect(Topic.exists?(category.topic_id)).to eq(true)
      expect(Post.find_by(topic_id: category.topic_id).raw).to eq(
        I18n.t("staff_category_description"),
      )
      expect(SiteSetting.staff_category_id).to eq(category.id)
    end

    context "with existing category" do
      before { seeder.create(site_setting_names: ["staff_category_id"]) }

      it "does not create another category" do
        expect { seeder.create(site_setting_names: ["staff_category_id"]) }.to not_change {
          Category.count
        }.and not_change { Topic.count }
      end

      it "creates a missing 'About Category' topic" do
        category = Category.last
        Topic.delete(category.topic_id)

        expect { seeder.create(site_setting_names: ["staff_category_id"]) }.to not_change {
          Category.count
        }.and change { Topic.count }.by(1)

        category.reload
        expect(Post.find_by(topic_id: category.topic_id).raw).to eq(
          I18n.t("staff_category_description"),
        )
      end

      it "overwrites permissions when permissions are forced" do
        category = Category.last
        category.set_permissions(everyone: :full)
        category.save!

        expect(category.category_groups.count).to eq(0)

        expect { seeder.create(site_setting_names: ["staff_category_id"]) }.to change {
          CategoryGroup.count
        }.by(1)

        category.reload
        expect(category.category_groups.count).to eq(1)
        expect(category.category_groups.first).to have_attributes(full_permissions_for_staff)
      end

      it "overwrites permissions even when subcategory has less restrictive permissions" do
        category = Category.last
        category.set_permissions(everyone: :full)
        category.save!

        group = Fabricate(:group)

        subcategory = Fabricate(:category, name: "child", parent_category_id: category.id)
        subcategory.set_permissions(group => :full)
        subcategory.save!

        expect { seeder.create(site_setting_names: ["staff_category_id"]) }.to change {
          CategoryGroup.count
        }.by(1)

        category.reload
        expect(category.category_groups.count).to eq(1)
        expect(category.category_groups.first).to have_attributes(full_permissions_for_staff)
      end
    end

    it "does not seed the general category for non-new sites" do
      Fabricate(:user) # If the site has human users don't seed

      expect { seeder.create(site_setting_names: ["general_category_id"]) }.to not_change {
        Category.count
      }.and not_change { Topic.count }
    end

    it "seeds the general category for new sites" do
      expect { seeder.create(site_setting_names: ["general_category_id"]) }.to change {
        Category.count
      }.and change { Topic.count }

      expect(Category.last.name).to eq("General")
      expect(SiteSetting.default_composer_category).to eq(Category.last.id)
    end

    it "adds emojis to seeded categories" do
      Category.destroy_all

      seeder.create(site_setting_names: ["uncategorized_category_id"])
      expect(Category.last.emoji).to eq("card_file_box")

      seeder.create(site_setting_names: ["meta_category_id"])
      expect(Category.last.emoji).to eq("thought_balloon")

      seeder.create(site_setting_names: ["staff_category_id"])
      expect(Category.last.emoji).to eq("shield")

      seeder.create(site_setting_names: ["general_category_id"])
      expect(Category.last.emoji).to eq("blue_book")
    end

    it "does not overwrite permissions on the General category" do
      seeder.create(site_setting_names: ["general_category_id"])
      expect(Category.last.name).to eq("General")
      category = Category.last

      expect(category.category_groups.count).to eq(0)

      category.set_permissions(staff: :full)
      category.save!

      expect(category.category_groups.count).to eq(1)

      expect { seeder.create(site_setting_names: ["general_category_id"]) }.not_to change {
        CategoryGroup.count
      }

      category.reload
      expect(category.category_groups.count).to eq(1)
      expect(category.category_groups.first).to have_attributes(full_permissions_for_staff)
    end

    it "adds default categories SiteSetting.default_navigation_menu_categories" do
      seeder.create(site_setting_names: ["staff_category_id"])
      staff_category = Category.last
      seeder.create(site_setting_names: ["meta_category_id"])
      site_feedback_category = Category.last
      seeder.create(site_setting_names: ["general_category_id"])
      general_category = Category.last
      site_setting_ids = SiteSetting.default_navigation_menu_categories.split("|")
      seeder.create(site_setting_names: ["uncategorized_category_id"])

      expect(site_setting_ids[0].to_i).to eq(staff_category.id)
      expect(site_setting_ids[1].to_i).to eq(site_feedback_category.id)
      expect(site_setting_ids[2].to_i).to eq(general_category.id)
      expect(site_setting_ids.count).to eq(3)
    end

    it "does not override permissions of existing category when not forced" do
      seeder.create(site_setting_names: ["general_category_id"])

      category = Category.last
      category.set_permissions(trust_level_2: :full)
      category.save!

      expect(category.category_groups.first).to have_attributes(full_permissions_for_trust_level_2)

      expect { seeder.create(site_setting_names: ["general_category_id"]) }.not_to change {
        CategoryGroup.count
      }

      category.reload
      expect(category.category_groups.first).to have_attributes(full_permissions_for_trust_level_2)
    end
  end

  describe "#update" do
    before do
      seeder.create(site_setting_names: ["staff_category_id"])
      Category.last.update!(name: "Foo", slug: "foo")
    end

    it "updates an existing category" do
      category = Category.last
      Post.find_by(topic_id: category.topic_id).revise(
        Discourse.system_user,
        raw: "Description for Foo category.",
      )

      seeder.update(site_setting_names: ["staff_category_id"], skip_changed: false)

      category.reload
      expect(category.name).to eq(I18n.t("staff_category_name"))
      expect(category.slug).to eq(Slug.for(I18n.t("staff_category_name")))
      expect(Post.find_by(topic_id: category.topic_id).raw).to eq(
        I18n.t("staff_category_description"),
      )
    end

    it "skips category when `skip_changed` is true and description was changed" do
      category = Category.last
      Post.find_by(topic_id: category.topic_id).revise(
        Fabricate(:admin),
        raw: "Description for Foo category.",
      )

      seeder.update(site_setting_names: ["staff_category_id"], skip_changed: true)

      category.reload
      expect(category.name).to eq("Foo")
      expect(category.slug).to eq("foo")
      expect(Post.find_by(topic_id: category.topic_id).raw).to eq("Description for Foo category.")
    end

    it "works when the category name is already used by another category" do
      Fabricate(:category, name: I18n.t("staff_category_name"))

      seeder.update(site_setting_names: ["staff_category_id"], skip_changed: false)

      category = Category.find(SiteSetting.staff_category_id)
      expect(category.name).to_not eq(I18n.t("staff_category_name"))
      expect(category.name).to start_with(I18n.t("staff_category_name"))
    end
  end

  describe "#reseed_options" do
    it "returns only existing categories as options" do
      seeder.create(site_setting_names: ["meta_category_id"])
      seeder.create(site_setting_names: ["general_category_id"])
      Post.last.revise(Fabricate(:admin), raw: "Hello world")

      expected_options = [
        {
          id: "uncategorized_category_id",
          name: I18n.t("uncategorized_category_name"),
          selected: true,
        },
        { id: "meta_category_id", name: I18n.t("meta_category_name"), selected: true },
        { id: "general_category_id", name: I18n.t("general_category_name"), selected: false },
      ]

      expect(seeder.reseed_options).to eq(expected_options)
    end
  end
end
