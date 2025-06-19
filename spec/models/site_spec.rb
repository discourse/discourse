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
    fab!(:category)
    fab!(:user)
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

        plugin_instance = Plugin::Instance.new
        modifier_block = Proc.new { |query| query.where("categories.name LIKE 'Cool%'") }
        plugin_instance.register_modifier(:site_all_categories_cache_query, &modifier_block)

        prefetched_categories = Site.new(Guardian.new(user)).categories.map { |c| c[:id] }

        expect(prefetched_categories).to include(cool_category.id)
        expect(prefetched_categories).not_to include(boring_category.id)
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :site_all_categories_cache_query,
          &modifier_block
        )
      end
    end

    context "with lazy loaded categories enabled" do
      fab!(:user)

      before { SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}" }

      it "does not return any categories for anonymous users" do
        site = Site.new(Guardian.new)

        expect(site.categories).to eq([])
      end

      it "returns only sidebar categories and their ancestors" do
        SiteSetting.max_category_nesting = 3
        grandfather_category = Fabricate(:category)
        parent_category = Fabricate(:category, parent_category: grandfather_category)
        category.update!(parent_category: parent_category)
        Fabricate(:category_sidebar_section_link, linkable: category, user: user)

        site = Site.new(Guardian.new(user))

        expect(site.categories.map { |c| c[:id] }).to contain_exactly(
          grandfather_category.id,
          parent_category.id,
          category.id,
        )
      end

      it "returns only visible sidebar categories" do
        Fabricate(:category_sidebar_section_link, linkable: category, user: user)
        category.update!(read_restricted: true)

        site = Site.new(Guardian.new(user))

        expect(site.categories).to eq([])
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
    fab!(:user)
    fab!(:cool_group) { Fabricate(:group, name: "cool-group") }
    fab!(:boring_group) { Fabricate(:group, name: "boring-group") }

    it "allows changing the query" do
      prefetched_groups = Site.new(Guardian.new(user)).groups.map { |c| c[:id] }
      expect(prefetched_groups).to include(cool_group.id, boring_group.id)

      # we need to clear the cache to ensure that the groups list will be updated
      Site.clear_cache

      plugin_instance = Plugin::Instance.new
      modifier_block = Proc.new { |query| query.where("groups.name LIKE 'cool%'") }
      plugin_instance.register_modifier(:site_groups_query, &modifier_block)

      prefetched_groups = Site.new(Guardian.new(user)).groups.map { |c| c[:id] }

      expect(prefetched_groups).to include(cool_group.id)
      expect(prefetched_groups).not_to include(boring_group.id)
    ensure
      DiscoursePluginRegistry.unregister_modifier(
        plugin_instance,
        :site_groups_query,
        &modifier_block
      )
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

  describe ".all_categories_cache" do
    fab!(:category)
    fab!(:category2) { Fabricate(:category) }

    it "returns cached categories" do
      categories_data = Site.all_categories_cache
      expect(categories_data.map { |c| c[:id] }).to contain_exactly(
        SiteSetting.uncategorized_category_id,
        category.id,
        category2.id,
      )
    end

    it "caches the result" do
      Site.all_categories_cache

      category2.update_columns(name: "derp")

      # The cached result should not contain
      # the updated name that skipped validations
      cached_names = Site.all_categories_cache.map { |c| c[:name] }
      expect(cached_names).not_to include("derp")

      Site.clear_cache
      refreshed_names = Site.all_categories_cache.map { |c| c[:name] }
      expect(refreshed_names).to include("derp")
    end

    it "includes preloaded custom fields" do
      Site.reset_preloaded_category_custom_fields
      Site.preloaded_category_custom_fields << "test_field"

      category.custom_fields["test_field"] = "test_value"
      category.save_custom_fields

      categories_data = Site.all_categories_cache
      category_data = categories_data.find { |c| c[:id] == category.id }

      expect(category_data[:custom_fields]["test_field"]).to eq("test_value")
    ensure
      Site.reset_preloaded_category_custom_fields
    end

    it "applies plugin modifiers to the query" do
      plugin_instance = Plugin::Instance.new
      modifier_block =
        Proc.new { |query| query.where("categories.name LIKE ?", "#{category.name}%") }

      plugin_instance.register_modifier(:site_all_categories_cache_query, &modifier_block)

      Site.clear_cache
      categories_data = Site.all_categories_cache

      expect(categories_data.map { |c| c[:id] }).to contain_exactly(category.id)
    ensure
      DiscoursePluginRegistry.unregister_modifier(
        plugin_instance,
        :site_all_categories_cache_query,
        &modifier_block
      )
    end

    describe "content_localization_enabled" do
      it "returns localized category names when enabled" do
        SiteSetting.content_localization_enabled = true

        localization = Fabricate(:category_localization)
        category = localization.category
        locale = localization.locale.to_sym

        I18n.locale = locale

        all_categories_cache = Site.all_categories_cache
        cached_category = all_categories_cache.find { |c| c[:id] == category.id }
        expect(cached_category[:name]).to eq(localization.name)
        expect(cached_category[:description]).to eq(localization.description)
      end

      it "returns original names when enabled" do
        SiteSetting.content_localization_enabled = true

        category = Fabricate(:category, name: "derp", description: "derp derp")

        all_categories_cache = Site.all_categories_cache
        cached_category = all_categories_cache.find { |c| c[:id] == category.id }
        expect(cached_category[:name]).to eq(category.name)
        expect(cached_category[:description]).to eq(category.description)
      end
    end
  end

  context "when there are anonymous users with different locales" do
    let(:anon_guardian) { Guardian.new }
    let(:original_locale) { I18n.locale }

    before do
      SiteSetting.login_required = false
      Discourse.redis.flushdb
      I18n.available_locales = %i[en ja]
      I18n.locale = :en
    end

    after do
      I18n.available_locales = nil
      I18n.locale = original_locale
    end

    context "when content_localization_enabled is disabled" do
      before { SiteSetting.content_localization_enabled = false }

      it "caches anon site json with a global key (not locale scoped)" do
        expect(Discourse.redis.get("site_json")).to be_nil

        json = Site.json_for(anon_guardian)

        expect(Discourse.redis.get("site_json")).to eq(json)

        I18n.locale = :ja
        json_ja = Site.json_for(anon_guardian)
        expect(Discourse.redis.get("site_json")).to eq(json_ja)

        # always overwritten, not per locale
        I18n.locale = :en
        expect(Discourse.redis.get("site_json")).to eq(json)
      end
    end

    context "when content_localization_enabled is enabled" do
      before { SiteSetting.content_localization_enabled = true }

      it "caches anon site json separately for each locale" do
        expect(Discourse.redis.get("site_json_en")).to be_nil
        expect(Discourse.redis.get("site_json_ja")).to be_nil

        json_en = Site.json_for(anon_guardian)
        expect(Discourse.redis.get("site_json_en")).to eq(json_en)

        I18n.locale = :ja
        json_ja = Site.json_for(anon_guardian)
        expect(Discourse.redis.get("site_json_ja")).to eq(json_ja)

        expect(json_en).not_to eq(json_ja)
      end
    end
  end
end
