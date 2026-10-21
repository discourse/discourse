# frozen_string_literal: true

RSpec.describe Migrations::Importer::Customizations::Plan::Builder do
  subject(:result) { described_class.new(diff, facts).build }

  let(:plan) { result.first }
  let(:trailer) { result.last }

  let(:facts_class) do
    Class.new do
      def settings
        {
          "title" => {
            type: :string,
          },
          "logo" => {
            type: :upload,
          },
          "notification_email" => {
            type: :email,
            hidden: true,
          },
          "openid_connect_client_secret" => {
            type: :string,
            secret: true,
          },
          "openid_connect_enabled" => {
            type: :bool,
          },
          "approve_unless_allowed_groups" => {
            type: :group_list,
          },
          "uncategorized_category_id" => {
            type: :category,
          },
          "some_api_key" => {
            type: :string,
          },
          "enable_welcome_banner" => {
            type: :bool,
            themeable: true,
          },
          "invite_only" => {
            type: :bool,
          },
          "reply_by_email_address" => {
            type: :email,
          },
          "pop3_polling_host" => {
            type: :string,
          },
          "min_new_topics_time" => {
            type: :integer,
            hidden: true,
          },
          "about_banner_image" => {
            type: :upload,
            hidden: true,
          },
          "extended_site_description" => {
            type: :string,
            hidden: true,
          },
          "extended_site_description_cooked" => {
            type: :string,
            hidden: true,
          },
          "email_custom_css" => {
            type: :string,
            hidden: true,
          },
          "email_custom_css_compiled" => {
            type: :string,
            hidden: true,
          },
          "maxmind_license_key_shadowed" => {
            type: :string,
            global: true,
          },
        }
      end

      def themes
        {
          -2 => {
            name: "Horizon",
            system: true,
            git: false,
          },
          5 => {
            name: "Custom component",
            system: false,
            git: false,
          },
          6 => {
            name: "Git component",
            system: false,
            git: true,
          },
        }
      end

      def site_setting(name)
        info = settings[name]
        info && { hidden: false, secret: false, themeable: false, global: false }.merge(info)
      end

      def automatic_group_id?(id)
        id.between?(0, 14)
      end

      def theme(id)
        themes[id]
      end

      def color_scheme(id)
        { 7 => { name: "Light palette", theme_id: nil }, 8 => { name: "Owned", theme_id: 5 } }[id]
      end

      def group(id)
        {
          1 => {
            name: "admins",
            automatic: true,
            imported: false,
            match: {
              "name" => "admins",
            },
          },
          50 => {
            name: "imported_group",
            automatic: false,
            imported: true,
            match: {
              "original_id" => 9,
              "name" => "imported_group",
            },
          },
          51 => {
            name: "local_group",
            automatic: false,
            imported: false,
            match: {
              "name" => "local_group",
            },
          },
        }[
          id
        ]
      end

      def category(id)
        {
          20 => {
            name: "Imported",
            imported: true,
            match: {
              "import_id" => "3",
              "slug_path" => "imported",
            },
          },
          21 => {
            name: "Local",
            imported: false,
            match: {
              "slug_path" => "local",
            },
          },
        }[
          id
        ]
      end

      def default_value?(_table, _column, value)
        value.nil? || value == "f" || value == "0"
      end

      def record_exists?(kind, id)
        { topic: [40], post: [41], user: [42], tag: [43] }.fetch(kind).include?(id)
      end
    end
  end
  let(:facts) { facts_class.new }

  def setting_row(id, name, value)
    { "id" => id.to_s, "name" => name, "data_type" => "1", "value" => value }
  end

  def permalink_row(id, url, target)
    columns = %w[topic_id post_id category_id tag_id user_id external_url].index_with { nil }
    { "id" => id.to_s, "url" => url, "updated_at" => "a" }.merge(columns).merge(target)
  end

  let(:diff) do
    {
      "tables" => {
        "site_settings" => {
          "added" => [
            setting_row(101, "title", "New title"),
            setting_row(102, "logo", "55"),
            setting_row(103, "notification_email", "a@example.com"),
            setting_row(104, "openid_connect_client_secret", "[redacted:0011aabb]"),
            setting_row(105, "openid_connect_enabled", "t"),
            setting_row(106, "approve_unless_allowed_groups", "1|2|10"),
            setting_row(107, "unknown_plugin_setting", "x"),
            setting_row(108, "some_api_key", "[redacted:22cc33dd]"),
            setting_row(109, "enable_welcome_banner", "f"),
            setting_row(110, "title_unchanged_marker", "x"),
            setting_row(111, "reply_by_email_address", "reply+%{reply_key}@example.com"),
            setting_row(112, "pop3_polling_host", "pop.example.com"),
            setting_row(113, "about_banner_image", "56"),
            setting_row(114, "extended_site_description", "About us"),
            setting_row(115, "email_custom_css_compiled", "a{}"),
            setting_row(116, "maxmind_license_key_shadowed", "abc"),
            setting_row(117, "min_new_topics_time", "1727802561"),
          ],
          "removed" => [
            setting_row(10, "logo", "12"),
            setting_row(11, "title_unchanged_marker", "x"),
            setting_row(12, "invite_only", "t"),
          ],
          "changed" => [
            {
              "key" => ["13"],
              "diffs" => {
                "value" => %w[1 2],
              },
              "after" => setting_row(13, "uncategorized_category_id", "2"),
            },
          ],
        },
        "themes" => {
          "added" => [
            { "id" => "5", "name" => "Custom component" },
            { "id" => "6", "name" => "Git component" },
          ],
          "changed" => [
            {
              "key" => ["-2"],
              "diffs" => {
                "color_scheme_id" => [nil, "7"],
                "updated_at" => %w[a b],
              },
              "after" => {
                "id" => "-2",
                "name" => "Horizon",
              },
            },
            {
              "key" => ["-1"],
              "diffs" => {
                "updated_at" => %w[a b],
              },
              "after" => {
                "id" => "-1",
                "name" => "Foundation",
              },
            },
          ],
        },
        "theme_fields" => {
          "changed" => [
            {
              "key" => ["900"],
              "diffs" => {
                "upload_id" => %w[1 2],
                "updated_at" => %w[a b],
              },
              "after" => {
                "id" => "900",
                "theme_id" => "-1",
                "name" => "screenshot_light",
                "type_id" => "7",
              },
            },
          ],
        },
        "color_schemes" => {
          "added" => [
            { "id" => "7", "name" => "Light palette", "theme_id" => nil },
            { "id" => "8", "name" => "Owned", "theme_id" => "5" },
          ],
        },
        "groups" => {
          "added" => [
            { "id" => "51", "name" => "local_group", "title" => "Locals", "primary_group" => "f" },
          ],
          "changed" => [
            {
              "key" => ["1"],
              "diffs" => {
                "bio_raw" => [nil, ""],
                "flair_icon" => ["", nil],
                "flair_upload_id" => [nil, "55"],
                "flair_bg_color" => [nil, "ff0000"],
                "user_count" => %w[1 2],
              },
              "after" => {
                "id" => "1",
                "name" => "admins",
              },
            },
            {
              "key" => ["50"],
              "diffs" => {
                "title" => [nil, "Members"],
                "email_password" => %w[a b],
              },
              "after" => {
                "id" => "50",
                "name" => "imported_group",
              },
            },
            {
              "key" => ["2"],
              "diffs" => {
                "user_count" => %w[1 2],
              },
              "after" => {
                "id" => "2",
                "name" => "moderators",
              },
            },
          ],
        },
        "categories" => {
          "changed" => [
            {
              "key" => ["20"],
              "diffs" => {
                "color" => %w[aaa bbb],
                "uploaded_logo_id" => ["4", nil],
                "topic_count" => %w[1 2],
              },
              "after" => {
                "id" => "20",
              },
            },
            {
              "key" => ["21"],
              "diffs" => {
                "text_color" => %w[aaa bbb],
              },
              "after" => {
                "id" => "21",
              },
            },
          ],
        },
        "category_groups" => {
          "added" => [
            { "id" => "301", "category_id" => "20", "group_id" => "50", "permission_type" => "1" },
            { "id" => "302", "category_id" => "21", "group_id" => "50", "permission_type" => "1" },
          ],
          "removed" => [
            { "id" => "201", "category_id" => "20", "group_id" => "50", "permission_type" => "1" },
            { "id" => "202", "category_id" => "21", "group_id" => "50", "permission_type" => "2" },
          ],
        },
        "translation_overrides" => {
          "added" => [
            {
              "id" => "1",
              "locale" => "en",
              "translation_key" => "js.login.oidc.title",
              "value" => "Log in",
            },
            {
              "id" => "2",
              "locale" => "en",
              "translation_key" => "js.topic.title",
              "value" => "Topic",
            },
          ],
        },
        "permalinks" => {
          "added" => [
            permalink_row(1, "external", "external_url" => "https://example.com"),
            permalink_row(2, "old-topic", "topic_id" => "40"),
            permalink_row(3, "deleted-post", "post_id" => "99"),
            permalink_row(4, "imported-category", "category_id" => "20"),
            permalink_row(5, "local-category", "category_id" => "21"),
            permalink_row(6, "renamed-new", "user_id" => "42"),
          ],
          "removed" => [
            permalink_row(7, "gone", "topic_id" => "98"),
            permalink_row(8, "renamed-old", "user_id" => "42"),
          ],
          "changed" => [
            {
              "key" => ["9"],
              "diffs" => {
                "topic_id" => ["40", nil],
                "tag_id" => [nil, "43"],
                "updated_at" => %w[a b],
              },
              "after" => permalink_row(9, "retargeted", "tag_id" => "43"),
            },
            {
              "key" => ["10"],
              "diffs" => {
                "updated_at" => %w[a b],
              },
              "after" => permalink_row(10, "touched", "topic_id" => "40"),
            },
          ],
        },
        "badges" => {
          "added" => [],
          "removed" => [],
          "changed" => [{ "key" => ["1"], "diffs" => {}, "after" => {} }],
        },
        "user_profiles" => {
          "added" => [],
          "removed" => [],
          "changed" => [],
        },
      },
    }
  end

  def settings
    plan["site_settings"].index_by { |item| item["name"] }
  end

  it "classifies site settings" do
    expect(settings["title"]).to eq("name" => "title", "target" => "template")
    expect(settings["logo"]["target"]).to eq("template")
    expect(settings["notification_email"]).to include(
      "target" => "skip",
      "note" => "hosting-managed",
    )
    expect(settings["unknown_plugin_setting"]).to include(
      "target" => "skip",
      "note" => "unknown setting",
    )
    expect(settings["enable_welcome_banner"]["target"]).to eq("skip")
    expect(settings["openid_connect_client_secret"]).to include(
      "target" => "migrated",
      "secret" => true,
      "note" => "login/SSO",
    )
    expect(settings["openid_connect_enabled"]).to include("target" => "migrated")
    expect(settings["approve_unless_allowed_groups"]["target"]).to eq("template")
    expect(settings["uncategorized_category_id"]["target"]).to eq("migrated")
    expect(settings["some_api_key"]).to include("target" => "migrated", "secret" => true)
  end

  it "skips hosting-managed settings" do
    expect(settings["reply_by_email_address"]).to include(
      "target" => "skip",
      "note" => "hosting-managed",
    )
    expect(settings["pop3_polling_host"]).to include(
      "target" => "skip",
      "note" => "hosting-managed",
    )
  end

  it "skips settings overridden by a global setting" do
    expect(settings["maxmind_license_key_shadowed"]).to include(
      "target" => "skip",
      "note" => "overridden by a global setting",
    )
  end

  it "skips hidden settings unless they are edited on their own admin pages" do
    expect(settings["min_new_topics_time"]).to include("target" => "skip", "note" => "hidden")
    %w[about_banner_image extended_site_description email_custom_css_compiled].each do |name|
      expect(settings[name]).to include("target" => "template")
    end
  end

  it "ignores settings re-added with the same value and resets removed ones" do
    expect(settings).not_to have_key("title_unchanged_marker")
    expect(settings["invite_only"]).to include("reset" => true, "target" => "template")
  end

  it "sends group_list settings with custom groups to the migrated target" do
    diff["tables"]["site_settings"]["added"] = [
      setting_row(1, "approve_unless_allowed_groups", "1|77"),
    ]
    expect(settings["approve_unless_allowed_groups"]["target"]).to eq("migrated")
  end

  it "detects changed themes and ignores system theme screenshot noise" do
    expect(plan["themes"]).to contain_exactly(
      { "name" => "Horizon", "system_id" => -2, "target" => "template" },
      { "name" => "Custom component", "target" => "template" },
      { "name" => "Git component", "target" => "template", "note" => "installed from git" },
    )
  end

  it "skips palettes owned by a non-system theme" do
    expect(plan["color_schemes"]).to contain_exactly(
      { "name" => "Light palette", "target" => "template" },
      { "name" => "Owned", "target" => "skip", "note" => "comes with theme 'Custom component'" },
    )
  end

  it "detects permission changes only when the set of permissions differs" do
    diff["tables"]["categories"]["changed"] = []
    categories = plan["categories"].index_by { |item| item["name"] }

    expect(categories.keys).to eq(["Local"])
    expect(categories["Local"]["attributes"]).to eq(["permissions"])
  end

  it "lists only transferable group attributes" do
    groups = plan["groups"].index_by { |item| item["name"] }

    expect(groups.keys).to contain_exactly("admins", "imported_group", "local_group")
    expect(groups["admins"]).to include(
      "target" => "template",
      "attributes" => %w[flair_upload flair_bg_color],
    )
    expect(groups["imported_group"]).to include(
      "target" => "migrated",
      "attributes" => ["title"],
      "match" => {
        "original_id" => 9,
        "name" => "imported_group",
      },
    )
    expect(groups["local_group"]).to include("target" => "template", "attributes" => ["title"])
  end

  it "pairs groups by name when their ids differ between the databases" do
    diff["tables"]["groups"] = {
      "added" => [{ "id" => "57", "name" => "ai_users", "full_name" => "AI users" }],
      "changed" => [
        {
          "key" => ["55"],
          "diffs" => {
            "name" => %w[ai_users local_group],
            "full_name" => ["AI users", "Locals"],
          },
          "after" => {
            "id" => "55",
            "name" => "local_group",
            "full_name" => "Locals",
          },
        },
      ],
    }
    facts.define_singleton_method(:group) do |id|
      { 55 => { name: "local_group", automatic: false, imported: false, match: {} } }[id] ||
        { name: "ai_users", automatic: true, imported: false, match: {} }
    end

    groups = plan["groups"].index_by { |item| item["name"] }

    expect(groups.keys).to eq(["local_group"])
    expect(groups["local_group"]["attributes"]).to eq(["full_name"])
    expect(trailer.join("\n")).not_to include("groups:")
  end

  it "classifies categories" do
    categories = plan["categories"].index_by { |item| item["name"] }

    expect(categories["Imported"]).to include(
      "target" => "migrated",
      "attributes" => %w[color uploaded_logo],
      "match" => {
        "import_id" => "3",
        "slug_path" => "imported",
      },
    )
    expect(categories["Local"]).to include(
      "target" => "template",
      "attributes" => %w[text_color permissions],
    )
  end

  it "sends login provider translation overrides to the migrated target" do
    expect(plan["translation_overrides"]).to contain_exactly(
      {
        "locale" => "en",
        "key" => "js.login.oidc.title",
        "target" => "migrated",
        "note" => "login/SSO",
      },
      { "locale" => "en", "key" => "js.topic.title", "target" => "template" },
    )
  end

  it "classifies permalinks by what they redirect to" do
    expect(plan["permalinks"]).to eq(
      [
        { "url" => "deleted-post", "target" => "skip", "note" => "post no longer exists" },
        { "url" => "external", "target" => "template" },
        {
          "url" => "gone",
          "remove" => true,
          "target" => "migrated",
          "note" => "redirects to a topic",
        },
        {
          "url" => "imported-category",
          "target" => "migrated",
          "note" => "redirects to an imported category",
        },
        { "url" => "local-category", "target" => "template", "note" => "redirects to a category" },
        { "url" => "old-topic", "target" => "migrated", "note" => "redirects to a topic" },
        { "url" => "renamed-new", "target" => "migrated", "note" => "redirects to a user" },
        {
          "url" => "renamed-old",
          "remove" => true,
          "target" => "migrated",
          "note" => "redirects to a user",
        },
        { "url" => "retargeted", "target" => "migrated", "note" => "redirects to a tag" },
      ],
    )
    expect(trailer.join("\n")).not_to include("permalinks")
  end

  it "lists unhandled tables in the trailer" do
    expect(trailer).to include(
      "Not handled, review manually:",
      "  badges: 0 added, 0 removed, 1 changed",
    )
    expect(trailer.join("\n")).not_to include("user_profiles")
    expect(trailer.join("\n")).not_to include("category_groups")
  end

  it "produces a plan that loads again" do
    yaml = Migrations::Importer::Customizations::Plan.dump(plan, trailer:)
    loaded = Migrations::Importer::Customizations::Plan.new(YAML.safe_load(yaml))

    expect(loaded.items("themes").size).to eq(3)
    expect(yaml).to include("# Not handled, review manually:")
  end
end
