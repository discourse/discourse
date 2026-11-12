# frozen_string_literal: true

RSpec.describe ApplicationLayoutPreloader do
  subject(:preloader) do
    described_class.new(
      guardian: guardian,
      theme_id: theme_id,
      theme_target: :desktop,
      login_method: nil,
    )
  end

  let(:theme_id) { nil }

  describe "#preloaded_data" do
    let(:guardian) { user.guardian }
    let(:preloaded_data) { subject.preloaded_data }

    context "when the user is anonymous" do
      let(:guardian) { Guardian.new }

      it "preloads the anonymous keys" do
        expect(preloaded_data.keys).to contain_exactly(
          "site",
          "siteSettings",
          "themeSiteSettingOverrides",
          "customHTML",
          "banner",
          "customEmoji",
          "isReadOnly",
          "isStaffWritesOnly",
          "activatedThemes",
          "upcomingChanges",
        )
      end
    end

    context "when the user is logged in" do
      fab!(:user)

      it "preloads permanent changes as enabled for users outside the stored groups" do
        group = Fabricate(:group)
        Fabricate(:site_setting_group, name: :enable_upload_debug_mode, group_ids: group.id.to_s)
        mock_upcoming_change_metadata(enable_upload_debug_mode: { status: :permanent })

        expect(JSON.parse(preloaded_data["upcomingChanges"])["enable_upload_debug_mode"]).to eq(
          true,
        )
      end

      it "preloads the current user keys" do
        expect(preloaded_data.keys).to contain_exactly(
          "site",
          "siteSettings",
          "themeSiteSettingOverrides",
          "customHTML",
          "banner",
          "customEmoji",
          "isReadOnly",
          "isStaffWritesOnly",
          "activatedThemes",
          "upcomingChanges",
          "currentUser",
          "topicTrackingStates",
          "topicTrackingStateMeta",
        )
      end
    end

    context "when the user is an admin" do
      fab!(:user, :admin)

      it "preloads the admin keys" do
        expect(preloaded_data.keys).to contain_exactly(
          "site",
          "siteSettings",
          "themeSiteSettingOverrides",
          "customHTML",
          "banner",
          "customEmoji",
          "isReadOnly",
          "isStaffWritesOnly",
          "activatedThemes",
          "upcomingChanges",
          "currentUser",
          "topicTrackingStates",
          "topicTrackingStateMeta",
          "fontMap",
          "visiblePlugins",
        )
      end
    end
  end

  describe "plugin preloaded data" do
    let(:guardian) { Guardian.new }
    let(:plugin) { Plugin::Instance.new(Plugin::Metadata.parse("# name: sample-plugin")) }

    around do |example|
      registrations = DiscoursePluginRegistry._raw_preloaded_data_callbacks.dup
      example.run
    ensure
      DiscoursePluginRegistry._raw_preloaded_data_callbacks.replace(registrations)
    end

    it "passes the request guardian and serializes namespaced values safely" do
      plugin.register_preloaded_data("site") do |request_guardian|
        { anonymous: request_guardian.anonymous?, content: "</script>" }
      end

      data = preloader.preloaded_data

      expect(JSON.parse(data["sample-plugin:site"])).to eq(
        "anonymous" => true,
        "content" => "</script>",
      )
      expect(data["sample-plugin:site"]).not_to include("</")
      expect(JSON.parse(data["site"])).to have_key("categories")
    end

    it "passes the authenticated request guardian" do
      user = Fabricate(:user)
      plugin.register_preloaded_data("user") { |request_guardian| request_guardian.user&.id }
      preloader =
        described_class.new(
          guardian: user.guardian,
          theme_id: nil,
          theme_target: :desktop,
          login_method: nil,
        )

      expect(JSON.parse(preloader.preloaded_data["sample-plugin:user"])).to eq(user.id)
    end

    it "omits nil values and preserves false values" do
      plugin.register_preloaded_data("omitted") { nil }
      plugin.register_preloaded_data("visible") { false }

      data = preloader.preloaded_data

      expect(data).not_to have_key("sample-plugin:omitted")
      expect(JSON.parse(data["sample-plugin:visible"])).to eq(false)
    end

    it "keeps matching keys from different plugins separate" do
      other_plugin = Plugin::Instance.new(Plugin::Metadata.parse("# name: other-plugin"))
      plugin.register_preloaded_data("visibility") { true }
      other_plugin.register_preloaded_data("visibility") { false }

      data = preloader.preloaded_data

      expect(JSON.parse(data["sample-plugin:visibility"])).to eq(true)
      expect(JSON.parse(data["other-plugin:visibility"])).to eq(false)
    end

    it "does not evaluate callbacks from disabled plugins" do
      plugin.enabled_site_setting(:discourse_sample_plugin_enabled)
      SiteSetting.discourse_sample_plugin_enabled = false
      plugin.register_preloaded_data("disabled") { raise "Disabled callback was evaluated" }

      expect(preloader.preloaded_data).not_to have_key("sample-plugin:disabled")
    end
  end

  describe "#activated_themes_json" do
    fab!(:user)
    fab!(:theme) { Fabricate(:theme, name: "Parent theme") }
    fab!(:component) { Fabricate(:theme, name: "Theme component", component: true) }
    fab!(:group)
    fab!(:other_group, :group)

    let(:guardian) { user.guardian }
    let(:activated_themes) { JSON.parse(subject.preloaded_data["activatedThemes"]) }

    before do
      theme.set_field(target: :settings, name: :yaml, value: <<~YAML)
        color:
          default: "red"
        allowed_groups:
          type: list
          list_type: group
          resolve_group_membership: true
          default: "#{group.id}"
        other_allowed_groups:
          type: list
          list_type: group
          resolve_group_membership: true
          default: "#{other_group.id}"
        menu_sections:
          type: objects
          default:
            - name: "member section"
              groups:
                - #{group.id}
              visible_groups:
                - #{other_group.id}
            - name: "other section"
              groups:
                - #{other_group.id}
              visible_groups:
                - #{group.id}
          schema:
            name: "section"
            properties:
              name:
                type: string
              groups:
                type: groups
                resolve_group_membership: true
              visible_groups:
                type: groups
      YAML

      component.set_field(target: :settings, name: :yaml, value: <<~YAML)
        component_setting:
          default: "enabled"
      YAML

      theme.save!
      component.save!
      group.add(user)
      theme.add_relative_theme!(:child, component)
    end

    context "without a theme id" do
      let(:theme_id) { nil }

      it "returns an empty object" do
        expect(activated_themes).to eq({})
      end
    end

    context "with an active theme" do
      let(:theme_id) { theme.id }

      it "preloads tag objects beside unchanged source-name selections" do
        tag = Fabricate(:tag, name: "support", locale: "en")
        Fabricate(:tag_localization, tag:, locale: "es", name: "ayuda")
        SiteSetting.content_localization_enabled = true
        component.set_field(target: :settings, name: :yaml, value: <<~YAML)
          tag_objects:
            default: "author setting"
          styles:
            type: objects
            default:
              - tags: [support]
            schema:
              name: style
              properties:
                tags:
                  type: tags
        YAML
        component.save!

        I18n.with_locale(:es) do
          expect(activated_themes.fetch(component.id.to_s)).to eq(
            "name" => component.name,
            "settings" => {
              "tag_objects" => "author setting",
              "styles" => [
                { "tags" => [tag.name], "tag_objects" => [{ "id" => tag.id, "name" => tag.name }] },
              ],
            },
          )
        end
      end

      it "leaves legacy tag lists unchanged" do
        tag = Fabricate(:tag, name: "support")
        component.set_field(target: :settings, name: :yaml, value: <<~YAML)
          selected_tags:
            type: list
            list_type: tag
            default: support
        YAML
        component.save!

        expect(activated_themes.fetch(component.id.to_s)).to eq(
          "name" => component.name,
          "settings" => {
            "selected_tags" => tag.name,
          },
        )
      end

      it "serializes the active theme and components" do
        expect(activated_themes).to eq(
          theme.id.to_s => {
            "name" => "Parent theme",
            "settings" => {
              "color" => "red",
              "user_in_allowed_groups" => true,
              "user_in_other_allowed_groups" => false,
              "menu_sections" => [
                {
                  "name" => "member section",
                  "user_in_groups" => true,
                  "visible_groups" => [other_group.id],
                },
                {
                  "name" => "other section",
                  "user_in_groups" => false,
                  "visible_groups" => [group.id],
                },
              ],
            },
          },
          component.id.to_s => {
            "name" => "Theme component",
            "settings" => {
              "component_setting" => "enabled",
            },
          },
        )
      end
    end

    context "with an anonymous user" do
      let(:guardian) { Guardian.new }
      let(:theme_id) { theme.id }

      it "resolves group settings for the anonymous guardian" do
        expect(activated_themes.dig(theme.id.to_s, "settings")).to include(
          "user_in_allowed_groups" => false,
          "user_in_other_allowed_groups" => false,
        )
      end
    end
  end
end
