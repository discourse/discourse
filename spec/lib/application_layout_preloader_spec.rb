# frozen_string_literal: true

RSpec.describe ApplicationLayoutPreloader do
  subject do
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
