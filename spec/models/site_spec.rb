# frozen_string_literal: true

RSpec.describe Site do
  after { Site.clear_cache }

  def expect_correct_themes(guardian)
    json = Site.json_for(guardian)
    parsed = JSON.parse(json)

    expected =
      Theme
        .where("id = :default OR user_selectable", default: SiteSetting.default_theme_id)
        .order(:name)
        .pluck(:id, :name, :color_scheme_id)
        .map do |id, n, cs|
          {
            "theme_id" => id,
            "name" => n,
            "default" => id == SiteSetting.default_theme_id,
            "color_scheme_id" => cs,
          }
        end

    expect(parsed["user_themes"]).to eq(expected)
  end

  it "includes user themes and expires them as needed" do
    default_theme = Fabricate(:theme)
    SiteSetting.default_theme_id = default_theme.id
    user_theme = Fabricate(:theme, user_selectable: true)
    second_user_theme = Fabricate(:theme, user_selectable: true)
    color_scheme = Fabricate(:color_scheme)

    anon_guardian = Guardian.new
    user_guardian = Guardian.new(Fabricate(:user))

    expect_correct_themes(anon_guardian)
    expect_correct_themes(user_guardian)

    Theme.clear_default!

    expect_correct_themes(anon_guardian)
    expect_correct_themes(user_guardian)

    user_theme.user_selectable = false
    user_theme.save!

    expect_correct_themes(anon_guardian)
    expect_correct_themes(user_guardian)

    second_user_theme.color_scheme_id = color_scheme.id
    second_user_theme.save!

    expect_correct_themes(anon_guardian)
    expect_correct_themes(user_guardian)
  end

  it "returns correct notification level for categories" do
    category = Fabricate(:category)
    guardian = Guardian.new
    expect(Site.new(guardian).categories.last[:notification_level]).to eq(1)
    SiteSetting.mute_all_categories_by_default = true
    expect(Site.new(guardian).categories.last[:notification_level]).to eq(0)
    SiteSetting.default_categories_tracking = category.id.to_s
    expect(Site.new(guardian).categories.last[:notification_level]).to eq(1)
  end

  describe "#categories" do
    fab!(:category) { Fabricate(:category) }
    fab!(:user) { Fabricate(:user) }
    let(:guardian) { Guardian.new(user) }

    it "omits read restricted categories" do
      expect(Site.new(guardian).categories.map { |c| c[:id] }).to contain_exactly(
        SiteSetting.uncategorized_category_id,
        category.id,
      )

      category.update!(read_restricted: true)

      expect(Site.new(guardian).categories.map { |c| c[:id] }).to contain_exactly(
        SiteSetting.uncategorized_category_id,
      )
    end

    it "includes categories that a user's group can see" do
      group = Fabricate(:group)
      category.update!(read_restricted: true)
      category.groups << group

      expect(Site.new(guardian).categories.map { |c| c[:id] }).to contain_exactly(
        SiteSetting.uncategorized_category_id,
      )

      group.add(user)

      expect(Site.new(Guardian.new(user)).categories.map { |c| c[:id] }).to contain_exactly(
        SiteSetting.uncategorized_category_id,
        category.id,
      )
    end

    it "omits categories users can not write to from the category list" do
      expect(Site.new(guardian).categories.count).to eq(2)

      category.set_permissions(everyone: :create_post)
      category.save!

      guardian = Guardian.new(user)

      expect(
        Site.new(guardian).categories.keep_if { |c| c[:name] == category.name }.first[:permission],
      ).not_to eq(CategoryGroup.permission_types[:full])

      # If a parent category is not visible, the child categories should not be returned
      category.set_permissions(staff: :full)
      category.save!

      sub_category = Fabricate(:category, parent_category_id: category.id)
      expect(Site.new(guardian).categories).not_to include(sub_category)
    end

    it "should clear the cache when custom fields are updated" do
      Site.preloaded_category_custom_fields << "enable_marketplace"
      categories = Site.new(Guardian.new).categories

      expect(categories.last[:custom_fields]["enable_marketplace"]).to eq(nil)

      category.custom_fields["enable_marketplace"] = true
      category.save_custom_fields

      categories = Site.new(Guardian.new).categories

      expect(categories.last[:custom_fields]["enable_marketplace"]).to eq("t")

      category.upsert_custom_fields(enable_marketplace: false)

      categories = Site.new(Guardian.new).categories

      expect(categories.last[:custom_fields]["enable_marketplace"]).to eq("f")
    ensure
      Site.reset_preloaded_category_custom_fields
    end

    it "sets the can_edit field for categories correctly" do
      categories = Site.new(Guardian.new).categories

      expect(categories.map { |c| c[:can_edit] }).to contain_exactly(false, false)

      site = Site.new(Guardian.new(Fabricate(:moderator)))

      expect(site.categories.map { |c| c[:can_edit] }).to contain_exactly(false, false)

      SiteSetting.moderators_manage_categories_and_groups = true

      site = Site.new(Guardian.new(Fabricate(:moderator)))

      expect(site.categories.map { |c| c[:can_edit] }).to contain_exactly(true, true)
    end

    describe "site_all_categories_cache_query modifier" do
      fab!(:cool_category) { Fabricate(:category, name: "Cool category") }
      fab!(:boring_category) { Fabricate(:category, name: "Boring category") }

      it "allows changing the query" do
        prefetched_categories = Site.new(Guardian.new(user)).categories.map { |c| c[:id] }
        expect(prefetched_categories).to include(cool_category.id, boring_category.id)

        # we need to clear the cache to ensure that the categories list will be updated
        Site.clear_cache

        Plugin::Instance
          .new
          .register_modifier(:site_all_categories_cache_query) do |query|
            query.where("categories.name LIKE 'Cool%'")
          end

        prefetched_categories = Site.new(Guardian.new(user)).categories.map { |c| c[:id] }

        expect(prefetched_categories).to include(cool_category.id)
        expect(prefetched_categories).not_to include(boring_category.id)
      ensure
        DiscoursePluginRegistry.clear_modifiers!
      end
    end
  end

  it "omits groups user can not see" do
    user = Fabricate(:user)
    site = Site.new(Guardian.new(user))

    staff_group = Fabricate(:group, visibility_level: Group.visibility_levels[:staff])
    expect(site.groups.pluck(:name)).not_to include(staff_group.name)

    public_group = Fabricate(:group)
    expect(site.groups.pluck(:name)).to include(public_group.name)

    admin = Fabricate(:admin)
    site = Site.new(Guardian.new(admin))
    expect(site.groups.pluck(:name)).to include(staff_group.name, public_group.name, "everyone")
  end

  describe "site_groups_query modifier" do
    fab!(:user) { Fabricate(:user) }
    fab!(:cool_group) { Fabricate(:group, name: "cool-group") }
    fab!(:boring_group) { Fabricate(:group, name: "boring-group") }

    it "allows changing the query" do
      prefetched_groups = Site.new(Guardian.new(user)).groups.map { |c| c[:id] }
      expect(prefetched_groups).to include(cool_group.id, boring_group.id)

      # we need to clear the cache to ensure that the groups list will be updated
      Site.clear_cache

      Plugin::Instance
        .new
        .register_modifier(:site_groups_query) { |query| query.where("groups.name LIKE 'cool%'") }

      prefetched_groups = Site.new(Guardian.new(user)).groups.map { |c| c[:id] }

      expect(prefetched_groups).to include(cool_group.id)
      expect(prefetched_groups).not_to include(boring_group.id)
    ensure
      DiscoursePluginRegistry.clear_modifiers!
    end
  end

  it "includes all enabled authentication providers" do
    SiteSetting.enable_twitter_logins = true
    SiteSetting.enable_facebook_logins = true
    data = JSON.parse(Site.json_for(Guardian.new))
    expect(data["auth_providers"].map { |a| a["name"] }).to contain_exactly("facebook", "twitter")
  end

  it "includes all enabled authentication providers for anon when login_required" do
    SiteSetting.login_required = true
    SiteSetting.enable_twitter_logins = true
    SiteSetting.enable_facebook_logins = true
    data = JSON.parse(Site.json_for(Guardian.new))
    expect(data["auth_providers"].map { |a| a["name"] }).to contain_exactly("facebook", "twitter")
  end
end
