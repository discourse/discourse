# frozen_string_literal: true

RSpec.describe "tasks/themes" do
  describe "themes:update" do
    let(:initial_repo) do
      about_json = <<~JSON
      {
        "name": "awesome theme",
        "about_url": "https://www.site.com/about",
        "license_url": "https://www.site.com/license",
        "theme_version": "1.0",
        "minimum_discourse_version": "1.0.0"
      }
      JSON

      settings_yaml = <<~YAML
      some_setting:
        type: string
        default: some default value
      string_setting:
        type: string
        default: default value
      YAML

      setup_git_repo(
        "about.json" => about_json,
        "common/header.html" => "I AM A HEADER",
        "settings.yml" => settings_yaml,
      )
    end

    let(:initial_repo_url) do
      MockGitImporter.register("https://example.com/initial_repo.git", initial_repo)
    end

    let!(:theme) { RemoteTheme.import_theme(initial_repo_url) }

    around(:each) { |group| MockGitImporter.with_mock { group.run } }

    after { `rm -fr #{initial_repo}` }

    it "should retain a theme's settings and not update the theme when a theme's setting fails to save" do
      theme.update_setting(:some_setting, "some setting value")

      migration_content = <<~JS
      export default function migrate(settings) {
        const oldSetting = settings.get("string_setting");
        settings.set("string_setting", [{}]);
        return settings;
      }
      JS

      settings_yaml = <<~YAML
      string_setting:
        type: objects
        default: []
        schema:
          name: some object
          properties:
            title:
              type: string
              required: true
      YAML

      add_to_git_repo(
        initial_repo,
        "migrations/settings/0001-a-migration.js" => migration_content,
        "settings.yml" => settings_yaml,
        "common/header.html" => "I AM UPDATED HEADER",
      )

      original_remote_version = theme.remote_theme.remote_version
      original_local_version = theme.remote_theme.local_version

      stderr = capture_stderr { capture_stdout { invoke_rake_task("themes:update") } }

      expect(stderr.chomp).to eq(
        "[default] Failed to update 'awesome theme' (#{theme.id}): The property at JSON Pointer '/0/title' must be present.",
      )

      theme.reload

      expect(theme.theme_fields.count).to eq(2)
      expect(theme.theme_fields.where(name: "header").first.value).to eq("I AM A HEADER")
      expect(theme.theme_settings_migrations.count).to eq(0)
      expect(theme.remote_theme.commits_behind).to eq(0)
      expect(theme.remote_theme.remote_version).to eq(original_remote_version)
      expect(theme.remote_theme.local_version).to eq(original_local_version)
      expect(theme.settings[:some_setting].value).to eq("some setting value")
      expect(theme.settings[:string_setting].value).to eq("default value")
    end

    it "should not update the theme if a theme setting migration fails during the update" do
      migration_content = <<~JS
      export default function migrate(settings) {
        throw "error";
      }
      JS

      add_to_git_repo(
        initial_repo,
        "migrations/settings/0001-a-migration.js" => migration_content,
        "common/header.html" => "I AM UPDATED HEADER",
      )

      original_remote_version = theme.remote_theme.remote_version
      original_local_version = theme.remote_theme.local_version

      capture_stderr { capture_stdout { invoke_rake_task("themes:update") } }

      theme.reload

      expect(theme.theme_fields.count).to eq(2)
      expect(theme.theme_fields.where(name: "header").first.value).to eq("I AM A HEADER")
      expect(theme.theme_settings_migrations.count).to eq(0)
      expect(theme.remote_theme.commits_behind).to eq(0)
      expect(theme.remote_theme.remote_version).to eq(original_remote_version)
      expect(theme.remote_theme.local_version).to eq(original_local_version)
    end
  end

  describe "themes:deduplicate_horizon" do
    fab!(:user)
    fab!(:remote_theme) do
      RemoteTheme.create!(
        remote_url: "https://github.com/discourse-org/horizon.git",
        minimum_discourse_version: "2.5.0",
      )
    end
    fab!(:remote_horizon_theme) do
      Fabricate(
        :theme,
        user: user,
        name: "Remote Horizon",
        remote_theme: remote_theme,
        user_selectable: true,
      )
    end
    fab!(:child_component) do
      Fabricate(:theme, user: user, component: true, name: "Child Component")
    end
    fab!(:theme_setting) do
      ThemeSetting.create!(
        theme: remote_horizon_theme,
        data_type: ThemeSetting.types[:bool],
        name: "enable_welcome_banner",
        value: "false",
      )
    end
    fab!(:remote_color_scheme) do
      remote_horizon_theme.color_schemes.create!(
        name: "Lily Dark",
        theme_id: remote_horizon_theme.id,
        user_selectable: false,
      )
    end
    fab!(:remote_color_scheme_2) do
      remote_horizon_theme.color_schemes.create!(
        name: "Violet Dark",
        theme_id: remote_horizon_theme.id,
        user_selectable: true,
      )
    end
    fab!(:theme_translation_override) do
      ThemeTranslationOverride.create!(
        theme: remote_horizon_theme,
        locale: "en",
        translation_key: "test.key",
        value: "Test Value",
      )
    end

    let!(:system_horizon_theme) { Theme.horizon_theme }
    let!(:system_color_scheme) { system_horizon_theme.color_schemes.where(name: "Lily Dark").first }
    let!(:system_color_scheme_2) do
      system_horizon_theme.color_schemes.where(name: "Violet Dark").first
    end

    before do
      remote_horizon_theme.update!(color_scheme: remote_color_scheme)
      remote_horizon_theme.add_relative_theme!(:child, child_component)
      remote_horizon_theme.save!
      user.user_option.update!(
        theme_ids: [remote_horizon_theme.id],
        color_scheme_id: remote_color_scheme.id,
        dark_scheme_id: remote_color_scheme.id,
      )
      SiteSetting.default_theme_id = remote_horizon_theme.id
    end

    context "when no horizon themes exist" do
      before do
        remote_horizon_theme.remote_theme&.destroy!
        remote_horizon_theme.destroy!
      end

      it "aborts with no themes message" do
        output =
          capture_stderr do
            expect { invoke_rake_task("themes:deduplicate_horizon") }.to raise_error(SystemExit)
          end
        expect(output).to include("🟩 No Horizon themes found")
      end
    end

    context "when multiple horizon themes exist" do
      fab!(:remote_theme_2) do
        RemoteTheme.create!(
          remote_url: "https://github.com/discourse/horizon.git",
          minimum_discourse_version: "2.5.0",
        )
      end
      fab!(:remote_horizon_theme_2) do
        Fabricate(:theme, user: user, name: "Second Horizon", remote_theme: remote_theme_2)
      end

      it "aborts with multiple themes message" do
        output =
          capture_stderr do
            expect { invoke_rake_task("themes:deduplicate_horizon") }.to raise_error(SystemExit)
          end
        expect(output).to include("⭕ More than one horizon theme installed")
      end
    end

    context "when exactly one horizon theme exists" do
      it "successfully migrates theme data" do
        expect(system_horizon_theme.user_selectable).to be false
        expect(SiteSetting.default_theme_id).to eq(remote_horizon_theme.id)
        expect(system_horizon_theme.child_themes).to eq([])
        expect(system_horizon_theme.theme_settings.pluck(:name)).to eq([])
        expect(system_horizon_theme.theme_translation_overrides.pluck(:translation_key)).to eq([])
        expect(system_horizon_theme.color_scheme.name).to eq("Horizon")
        expect {
          capture_stdout { invoke_rake_task("themes:deduplicate_horizon") }
        }.not_to raise_error

        expect { remote_horizon_theme.reload }.to raise_error(ActiveRecord::RecordNotFound)

        system_horizon_theme.reload
        expect(system_horizon_theme.user_selectable).to be true
        expect(SiteSetting.default_theme_id).to eq(system_horizon_theme.id)
        expect(system_horizon_theme.child_themes).to include(child_component)
        expect(system_horizon_theme.theme_settings.pluck(:name)).to include(theme_setting.name)
        expect(system_horizon_theme.theme_translation_overrides.pluck(:translation_key)).to include(
          "test.key",
        )
        expect(system_horizon_theme.color_scheme).to eq(system_color_scheme)
        expect(system_color_scheme.reload.user_selectable).to be true
        expect(system_color_scheme_2.reload.user_selectable).to be true
      end

      it "logs that remote theme was deleted" do
        expect {
          capture_stderr { capture_stdout { invoke_rake_task("themes:deduplicate_horizon") } }
        }.to change { UserHistory.count }

        expect(UserHistory.last.action).to eq(UserHistory.actions[:delete_theme])
        expect(UserHistory.last.subject).to eq("Remote Horizon")
      end

      it "updates user theme and color scheme" do
        expect(user.user_option.theme_ids).to eq([remote_horizon_theme.id])
        expect(user.user_option.color_scheme_id).to eq(remote_color_scheme.id)
        expect(user.user_option.dark_scheme_id).to eq(remote_color_scheme.id)

        capture_stdout { invoke_rake_task("themes:deduplicate_horizon") }

        user.user_option.reload
        expect(user.user_option.theme_ids).to eq([system_horizon_theme.id])
        expect(user.user_option.color_scheme_id).to eq(system_color_scheme.id)
        expect(user.user_option.dark_scheme_id).to eq(system_color_scheme.id)
      end

      it "does not update user color scheme if custom" do
        custom_color_scheme = Fabricate(:color_scheme)
        user.user_option.update!(color_scheme_id: custom_color_scheme.id)

        expect { capture_stdout { invoke_rake_task("themes:deduplicate_horizon") } }.not_to change {
          user.user_option.color_scheme_id
        }
      end

      it "enables system horizon theme if not already enabled" do
        SiteSetting.experimental_system_themes = "foundation"

        capture_stdout { invoke_rake_task("themes:deduplicate_horizon") }
        expect(SiteSetting.experimental_system_themes_map).to eq(%w[foundation horizon])
      end

      it "does not modify system themes setting if horizon already enabled" do
        SiteSetting.experimental_system_themes = "horizon"

        capture_stdout { invoke_rake_task("themes:deduplicate_horizon") }
        expect(SiteSetting.experimental_system_themes_map).to eq(%w[horizon])
      end
    end
  end
end
