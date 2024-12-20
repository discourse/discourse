# frozen_string_literal: true

RSpec.describe SiteSerializer do
  let(:guardian) { Guardian.new }
  let(:category) { Fabricate(:category) }

  after { Site.clear_cache }

  describe "#user_tips" do
    it "is included if enable_user_tips" do
      SiteSetting.enable_user_tips = true

      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
      expect(serialized[:user_tips]).to eq(User.user_tips)
    end

    it "is not included if enable_user_tips is disabled" do
      SiteSetting.enable_user_tips = false

      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
      expect(serialized[:user_tips]).to eq(nil)
    end
  end

  it "includes category custom fields only if its preloaded" do
    category.custom_fields["enable_marketplace"] = true
    category.save_custom_fields

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    c1 = serialized[:categories].find { |c| c[:id] == category.id }

    expect(c1[:custom_fields]).to eq(nil)

    Site.preloaded_category_custom_fields << "enable_marketplace"
    Site.clear_cache

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    c1 = serialized[:categories].find { |c| c[:id] == category.id }

    expect(c1[:custom_fields]["enable_marketplace"]).to eq("t")
  ensure
    Site.reset_preloaded_category_custom_fields
  end

  it "includes category tags" do
    tag = Fabricate(:tag)
    tag_group = Fabricate(:tag_group)
    tag_group_2 = Fabricate(:tag_group)

    category.tags << tag
    category.tag_groups << tag_group
    category.update!(
      category_required_tag_groups: [
        CategoryRequiredTagGroup.new(tag_group: tag_group_2, min_count: 1),
      ],
    )

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    c1 = serialized[:categories].find { |c| c[:id] == category.id }

    expect(c1[:allowed_tags]).to contain_exactly(tag.name)
    expect(c1[:allowed_tag_groups]).to contain_exactly(tag_group.name)
    expect(c1[:required_tag_groups]).to eq([{ name: tag_group_2.name, min_count: 1 }])
  end

  it "doesn't explode when category_required_tag_group is missing" do
    tag = Fabricate(:tag)
    tag_group = Fabricate(:tag_group)
    crtg = CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1)
    category.update!(category_required_tag_groups: [crtg])

    tag_group.delete # Bypassing hooks like this should never happen in the app

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    c1 = serialized[:categories].find { |c| c[:id] == category.id }

    expect(c1[:required_tag_groups]).to eq([{ name: nil, min_count: 1 }])
  end

  it "returns correct notification level for categories" do
    SiteSetting.mute_all_categories_by_default = true
    SiteSetting.default_categories_normal = category.id.to_s

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    categories = serialized[:categories]
    expect(categories[0][:notification_level]).to eq(0)
    expect(categories[-1][:notification_level]).to eq(1)
  end

  it "includes user-selectable color schemes" do
    # it includes seeded color schemes
    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    expect(serialized[:user_color_schemes].count).to eq(6)

    scheme_names = serialized[:user_color_schemes].map { |x| x[:name] }
    expect(scheme_names).to include(I18n.t("color_schemes.dark"))
    expect(scheme_names).to include(I18n.t("color_schemes.wcag"))
    expect(scheme_names).to include(I18n.t("color_schemes.wcag_dark"))
    expect(scheme_names).to include(I18n.t("color_schemes.solarized_light"))
    expect(scheme_names).to include(I18n.t("color_schemes.solarized_dark"))
    expect(scheme_names).to include(I18n.t("color_schemes.dracula"))

    dark_scheme = ColorScheme.create_from_base(name: "AnotherDarkScheme", base_scheme_id: "Dark")
    dark_scheme.user_selectable = true
    dark_scheme.save!

    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    expect(serialized[:user_color_schemes].count).to eq(7)
    expect(serialized[:user_color_schemes][0][:is_dark]).to eq(true)
  end

  it "includes default dark mode scheme" do
    scheme = ColorScheme.last
    SiteSetting.default_dark_mode_color_scheme_id = scheme.id
    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    default_dark_scheme = expect(serialized[:default_dark_color_scheme][:name]).to eq(scheme.name)

    SiteSetting.default_dark_mode_color_scheme_id = -1
    serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
    expect(serialized[:default_dark_color_scheme]).to eq(nil)
  end

  it "does not include shared_drafts_category_id if the category is Uncategorized" do
    admin = Fabricate(:admin)
    admin_guardian = Guardian.new(admin)

    SiteSetting.shared_drafts_category = SiteSetting.uncategorized_category_id

    serialized =
      described_class.new(Site.new(admin_guardian), scope: admin_guardian, root: false).as_json
    expect(serialized[:shared_drafts_category_id]).to eq(nil)
  end

  context "with lazy loaded categories enabled" do
    fab!(:user)
    fab!(:category)
    fab!(:sidebar) { Fabricate(:category_sidebar_section_link, linkable: category, user: user) }

    before { SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}" }

    it "does not include any categories for anonymous users" do
      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(serialized[:categories]).to eq(nil)
    end

    it "includes preloaded categories for logged in users" do
      guardian = Guardian.new(user)

      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(serialized[:categories].map { |c| c[:id] }).to contain_exactly(category.id)
    end
  end

  describe "#anonymous_default_navigation_menu_tags" do
    fab!(:user)
    fab!(:tag) { Fabricate(:tag, name: "dev", description: "some description") }
    fab!(:tag2) { Fabricate(:tag, name: "random") }
    fab!(:hidden_tag) { Fabricate(:tag, name: "secret") }

    fab!(:staff_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end

    before do
      SiteSetting.navigation_menu = "sidebar"
      SiteSetting.tagging_enabled = true
      SiteSetting.default_navigation_menu_tags = "#{tag.name}|#{tag2.name}|#{hidden_tag.name}"
    end

    it "is not included in the serialised object when tagging is not enabled" do
      SiteSetting.tagging_enabled = false
      guardian = Guardian.new(user)

      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
      expect(serialized[:anonymous_default_navigation_menu_tags]).to eq(nil)
    end

    it "is not included in the serialised object when user is not anonymous" do
      guardian = Guardian.new(user)

      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
      expect(serialized[:anonymous_default_navigation_menu_tags]).to eq(nil)
    end

    it "is not included in the serialisd object when default sidebar tags have not been configured" do
      SiteSetting.default_navigation_menu_tags = ""

      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
      expect(serialized[:anonymous_default_navigation_menu_tags]).to eq(nil)
    end

    it "includes only tags user can see in the serialised object when user is anonymous" do
      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(serialized[:anonymous_default_navigation_menu_tags]).to eq(
        [
          { name: "dev", description: "some description", pm_only: false },
          { name: "random", description: tag2.description, pm_only: false },
        ],
      )
    end
  end

  describe "#anonymous_sidebar_sections" do
    fab!(:user)
    fab!(:public_sidebar_section) do
      Fabricate(:sidebar_section, title: "Public section", public: true)
    end
    fab!(:private_sidebar_section) do
      Fabricate(:sidebar_section, title: "Private section", user: user, public: false)
    end

    it "is not included in the serialised object when user is not anonymous" do
      guardian = Guardian.new(user)
      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
      expect(serialized).not_to have_key(:anonymous_sidebar_sections)
    end

    it "includes only public sidebar sections serialised object when user is anonymous" do
      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json
      expect(serialized[:anonymous_sidebar_sections].map { |section| section[:title] }).to eq(
        ["Community", "Public section"],
      )
    end

    it "eager loads sidebar_urls" do
      public_section_link =
        Fabricate(:custom_sidebar_section_link, user: user, sidebar_section: public_sidebar_section)
      # warmup
      described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      initial_count =
        track_sql_queries do
          serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

          expect(serialized[:anonymous_sidebar_sections].count).to eq(2)

          expect(serialized[:anonymous_sidebar_sections].last[:links].map { |link| link.id }).to eq(
            [public_section_link.linkable.id],
          )
        end.count

      public_section_link_2 =
        Fabricate(:custom_sidebar_section_link, user: user, sidebar_section: public_sidebar_section)
      public_section_link_3 =
        Fabricate(:custom_sidebar_section_link, user: user, sidebar_section: public_sidebar_section)

      final_count =
        track_sql_queries do
          serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

          expect(serialized[:anonymous_sidebar_sections].count).to eq(2)

          expect(serialized[:anonymous_sidebar_sections].last[:links].map { |link| link.id }).to eq(
            [
              public_section_link.linkable.id,
              public_section_link_2.linkable.id,
              public_section_link_3.linkable.id,
            ],
          )
        end.count
      expect(final_count).to eq(initial_count)
    end
  end

  describe "#top_tags" do
    fab!(:tag)

    describe "when tagging is not enabled" do
      before { SiteSetting.tagging_enabled = false }

      it "is not included in the serialised object" do
        serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

        expect(serialized[:top_tags]).to eq(nil)
      end
    end

    describe "when tagging is enabled" do
      fab!(:tag2) { Fabricate(:tag) }
      fab!(:tag3) { Fabricate(:tag) }

      before { SiteSetting.tagging_enabled = true }

      it "is not included in the serialised object when there are no tags" do
        tag.destroy!

        serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

        expect(serialized[:top_tags]).to eq([])
      end

      it "is included in the serialised object containing the top tags" do
        tag2 = Fabricate(:tag)
        tag2 = Fabricate(:tag)

        SiteSetting.max_tags_in_filter_list = 1

        CategoryTagStat.create!(
          category_id: SiteSetting.uncategorized_category_id,
          tag_id: tag2.id,
          topic_count: 2,
        )
        CategoryTagStat.create!(
          category_id: SiteSetting.uncategorized_category_id,
          tag_id: tag.id,
          topic_count: 1,
        )
        CategoryTagStat.create!(
          category_id: SiteSetting.uncategorized_category_id,
          tag_id: tag3.id,
          topic_count: 5,
        )

        serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

        expect(serialized[:top_tags]).to eq([tag3.name, tag2.name])
      end
    end
  end

  describe "#navigation_menu_site_top_tags" do
    fab!(:tag1) do
      Fabricate(:tag, name: "tag 1").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
    end

    fab!(:tag2) do
      Fabricate(:tag, name: "tag 2").tap { |tag| Fabricate.times(1, :topic, tags: [tag]) }
    end

    fab!(:tag3) do
      Fabricate(:tag, name: "tag 3").tap { |tag| Fabricate.times(3, :topic, tags: [tag]) }
    end

    fab!(:hidden_tag) do
      Fabricate(:tag, name: "tag 4").tap { |tag| Fabricate.times(4, :topic, tags: [tag]) }
    end

    fab!(:staff_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end

    it "should return the site's top tags as the default tags for sidebar" do
      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(serialized[:navigation_menu_site_top_tags]).to eq(
        [
          { name: tag3.name, description: tag2.description, pm_only: false },
          { name: tag1.name, description: tag1.description, pm_only: false },
          { name: tag2.name, description: tag3.description, pm_only: false },
        ],
      )
    end

    it "should not be serialized if `tagging_enabled` site setting is set to false" do
      SiteSetting.set(:tagging_enabled, false)

      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(serialized[:navigation_menu_site_top_tags]).to eq(nil)
    end

    it "should return an empty array if site has no top tags" do
      Tag.delete_all

      serialized = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(serialized[:navigation_menu_site_top_tags]).to eq([])
    end
  end

  describe "#whispers_allowed_groups_names" do
    fab!(:admin)
    fab!(:allowed_user) { Fabricate(:user) }
    fab!(:not_allowed_user) { Fabricate(:user) }
    fab!(:group1) { Fabricate(:group, name: "whisperers1", users: [allowed_user]) }
    fab!(:group2) { Fabricate(:group, name: "whisperers2", users: [allowed_user]) }

    it "returns correct group names for created groups" do
      admin_guardian = Guardian.new(admin)
      SiteSetting.whispers_allowed_groups = "#{group1.id}|#{group2.id}"

      serialized =
        described_class.new(Site.new(admin_guardian), scope: admin_guardian, root: false).as_json
      expect(serialized[:whispers_allowed_groups_names]).to contain_exactly(
        "whisperers1",
        "whisperers2",
      )
    end

    it "returns correct group names for automatic groups" do
      admin_guardian = Guardian.new(admin)
      SiteSetting.whispers_allowed_groups =
        "#{Group::AUTO_GROUPS[:staff]}|#{Group::AUTO_GROUPS[:trust_level_4]}"

      serialized =
        described_class.new(Site.new(admin_guardian), scope: admin_guardian, root: false).as_json
      expect(serialized[:whispers_allowed_groups_names]).to contain_exactly(
        "trust_level_4",
        "staff",
      )
    end

    it "returns group names when user is allowed to whisper" do
      user_guardian = Guardian.new(allowed_user)
      SiteSetting.whispers_allowed_groups = "#{group1.id}|#{group2.id}"

      serialized =
        described_class.new(Site.new(user_guardian), scope: user_guardian, root: false).as_json
      expect(serialized[:whispers_allowed_groups_names]).to contain_exactly(
        "whisperers1",
        "whisperers2",
      )
    end

    it "returns nil when user is not allowed to whisper" do
      user_guardian = Guardian.new(not_allowed_user)
      SiteSetting.whispers_allowed_groups =
        "#{Group::AUTO_GROUPS[:staff]}|#{Group::AUTO_GROUPS[:trust_level_4]}"

      serialized =
        described_class.new(Site.new(user_guardian), scope: user_guardian, root: false).as_json
      expect(serialized[:whispers_allowed_groups_names]).to eq(nil)
    end
  end
end
