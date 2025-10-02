# frozen_string_literal: true

RSpec.describe RemoteTheme do
  before do
    FastImage
      .stubs(:size)
      .with { |arg| arg.match(%r{/screenshots/light\.jpeg}) }
      .returns([800, 600])
    FastImage
      .stubs(:size)
      .with { |arg| arg.match(%r{/screenshots/dark\.jpeg}) }
      .returns([1024, 768])
  end

  describe "#import_theme" do
    def about_json(
      love_color: "FAFAFA",
      tertiary_low_color: "FFFFFF",
      color_scheme_name: "Amazing",
      about_url: "https://www.site.com/about",
      screenshots: %w[screenshots/light.jpeg screenshots/dark.jpeg]
    )
      <<~JSON
        {
          "name": "awesome theme",
          "about_url": "#{about_url}",
          "license_url": "https://www.site.com/license",
          "theme_version": "1.0",
          "minimum_discourse_version": "1.0.0",
          "assets": {
            "font": "assets/font.woff2"
          },
          "color_schemes": {
            "#{color_scheme_name}": {
              "love": "#{love_color}",
              "tertiary-low": "#{tertiary_low_color}"
            }
          },
          "modifiers": {
            "serialize_topic_excerpts": true,
            "custom_homepage": {
              "type": "setting",
              "value": "boolean_setting"
            },
            "serialize_post_user_badges": {
              "type": "setting",
              "value": "list_setting"
            }
          },
          "screenshots": #{screenshots.to_json}
        }
      JSON
    end

    let :scss_data do
      "@font-face { font-family: magic; src: url($font)}; body {color: $color; content: $name;}"
    end

    let(:migration_js) { <<~JS }
        export default function migrate(settings) {
          return settings;
        }
      JS

    let :initial_repo do
      settings = <<~YAML
        boolean_setting: true
        list_setting:
          type: list
          default: ""
      YAML
      setup_git_repo(
        "about.json" => about_json,
        "desktop/desktop.scss" => scss_data,
        "scss/oldpath.scss" => ".class2{color:blue}",
        "stylesheets/file.scss" => ".class1{color:red}",
        "stylesheets/empty.scss" => "",
        "javascripts/discourse/controllers/test.js.es6" => "console.log('test');",
        "test/acceptance/theme-test.js" => "assert.ok(true);",
        "common/header.html" => "I AM HEADER",
        "common/random.html" => "I AM SILLY",
        "common/embedded.scss" => "EMBED",
        "common/color_definitions.scss" => ":root{--color-var: red}",
        "assets/font.woff2" => "FAKE FONT",
        "settings.yaml" => settings,
        "locales/en.yml" => "sometranslations",
        "migrations/settings/0001-some-migration.js" => migration_js,
        "screenshots/light.jpeg" => file_from_fixtures("logo.jpg", "images"),
        "screenshots/dark.jpeg" => file_from_fixtures("logo.jpg", "images"),
      )
    end

    let :initial_repo_url do
      MockGitImporter.register("https://example.com/initial_repo.git", initial_repo)
    end

    after { `rm -fr #{initial_repo}` }

    around(:each) { |group| MockGitImporter.with_mock { group.run } }

    it "run pending theme settings migrations" do
      add_to_git_repo(initial_repo, "migrations/settings/0002-another-migration.js" => <<~JS)
        export default function migrate(settings) {
          settings.set("boolean_setting", false);
          return settings;
        }
      JS
      theme = RemoteTheme.import_theme(initial_repo_url)
      migrations = theme.theme_settings_migrations.order(:version)

      expect(migrations.size).to eq(2)

      first_migration = migrations[0]
      second_migration = migrations[1]

      expect(first_migration.version).to eq(1)
      expect(second_migration.version).to eq(2)

      expect(first_migration.name).to eq("some-migration")
      expect(second_migration.name).to eq("another-migration")

      expect(first_migration.diff).to eq("additions" => [], "deletions" => [])
      expect(second_migration.diff).to eq(
        "additions" => [{ "key" => "boolean_setting", "val" => false }],
        "deletions" => [],
      )

      expect(theme.get_setting(:boolean_setting)).to eq(false)

      expect(first_migration.theme_field.value).to eq(<<~JS)
        export default function migrate(settings) {
          return settings;
        }
      JS
      expect(second_migration.theme_field.value).to eq(<<~JS)
        export default function migrate(settings) {
          settings.set("boolean_setting", false);
          return settings;
        }
      JS
    end

    it "doesn't create theme if a migration fails" do
      add_to_git_repo(initial_repo, "migrations/settings/0002-another-migration.js" => <<~JS)
        export default function migrate(s) {
          return null;
        }
      JS
      expect do RemoteTheme.import_theme(initial_repo_url) end.to raise_error(
        Theme::SettingsMigrationError,
      ).and not_change(Theme, :count).and not_change(RemoteTheme, :count)
    end

    it "doesn't partially update the theme when a migration fails" do
      theme = RemoteTheme.import_theme(initial_repo_url)

      add_to_git_repo(
        initial_repo,
        "about.json" =>
          JSON
            .parse(about_json(about_url: "https://updated.site.com"))
            .tap { |h| h[:component] = true }
            .to_json,
        "stylesheets/file.scss" => ".class3 { color: green; }",
        "common/header.html" => "I AM UPDATED HEADER",
        "migrations/settings/0002-new-failing-migration.js" => <<~JS,
          export default function migrate(settings) {
            null.toString();
            return settings;
          }
        JS
      )

      expect do theme.remote_theme.update_from_remote end.to raise_error(
        Theme::SettingsMigrationError,
      )

      theme.reload

      expect(theme.component).to eq(false)
      expect(theme.remote_theme.about_url).to eq("https://www.site.com/about")

      expect(theme.theme_fields.find_by(name: "header").value).to eq("I AM HEADER")
      expect(
        theme.theme_fields.find_by(type_id: ThemeField.types[:scss], name: "file").value,
      ).to eq(".class1{color:red}")
    end

    it "can correctly import a remote theme" do
      time = Time.new("2000")
      freeze_time time

      theme = RemoteTheme.import_theme(initial_repo_url)
      remote = theme.remote_theme

      expect(theme.name).to eq("awesome theme")
      expect(remote.remote_url).to eq(initial_repo_url)
      expect(remote.remote_version).to eq(`cd #{initial_repo} && git rev-parse HEAD`.strip)
      expect(remote.local_version).to eq(`cd #{initial_repo} && git rev-parse HEAD`.strip)

      expect(remote.about_url).to eq("https://www.site.com/about")
      expect(remote.license_url).to eq("https://www.site.com/license")
      expect(remote.theme_version).to eq("1.0")
      expect(remote.minimum_discourse_version).to eq("1.0.0")

      expect(theme.theme_modifier_set.serialize_topic_excerpts).to eq(true)
      expect(theme.theme_modifier_set.custom_homepage).to eq(true)

      expect(theme.theme_fields.length).to eq(15)

      mapped = Hash[*theme.theme_fields.map { |f| ["#{f.target_id}-#{f.name}", f.value] }.flatten]

      expect(mapped["0-header"]).to eq("I AM HEADER")
      expect(mapped["1-scss"]).to eq(scss_data)
      expect(mapped["0-embedded_scss"]).to eq("EMBED")
      expect(mapped["0-color_definitions"]).to eq(":root{--color-var: red}")

      expect(mapped["0-font"]).to eq("")

      expect(mapped["3-yaml"]).to eq(
        "boolean_setting: true\nlist_setting:\n  type: list\n  default: \"\"\n",
      )

      expect(mapped["4-en"]).to eq("sometranslations")
      expect(mapped["7-acceptance/theme-test.js"]).to eq("assert.ok(true);")
      expect(mapped["8-0001-some-migration"]).to eq(
        "export default function migrate(settings) {\n  return settings;\n}\n",
      )

      expect(mapped.length).to eq(15)

      expect(theme.settings.length).to eq(2)
      expect(theme.settings[:boolean_setting].value).to eq(true)
      expect(theme.settings[:list_setting].value).to eq("")

      # lets change the setting to see modifier reflects
      theme.update_setting(:boolean_setting, false)
      theme.update_setting(:list_setting, "badge1|badge2")
      theme.save!
      theme.reload

      expect(theme.theme_modifier_set.custom_homepage).to eq(false)
      expect(theme.theme_modifier_set.serialize_post_user_badges).to eq(%w[badge1 badge2])
      expect(remote.remote_updated_at).to eq_time(time)

      scheme = ColorScheme.find_by(theme_id: theme.id)
      expect(scheme.name).to eq("Amazing")
      expect(scheme.colors.find_by(name: "love").hex).to eq("fafafa")
      expect(scheme.colors.find_by(name: "tertiary-low").hex).to eq("ffffff")

      expect(theme.color_scheme_id).to eq(scheme.id)
      theme.update(color_scheme_id: nil)

      File.write("#{initial_repo}/common/header.html", "I AM UPDATED")
      File.write(
        "#{initial_repo}/about.json",
        about_json(love_color: "EAEAEA", about_url: "https://newsite.com/about"),
      )

      File.write("#{initial_repo}/settings.yml", "integer_setting: 32")
      `cd #{initial_repo} && git add settings.yml`

      File.delete("#{initial_repo}/settings.yaml")
      File.delete("#{initial_repo}/stylesheets/file.scss")
      `cd #{initial_repo} && git commit -am "update"`

      time = Time.new("2001")
      freeze_time time

      remote.update_remote_version
      expect(remote.commits_behind).to eq(1)
      expect(remote.remote_version).to eq(`cd #{initial_repo} && git rev-parse HEAD`.strip)

      remote.update_from_remote
      theme.reload

      scheme = ColorScheme.find_by(theme_id: theme.id)
      expect(scheme.name).to eq("Amazing")
      expect(scheme.colors.find_by(name: "love").hex).to eq("eaeaea")
      expect(theme.color_scheme_id).to eq(nil) # Should only be set on first import

      mapped = Hash[*theme.theme_fields.map { |f| ["#{f.target_id}-#{f.name}", f.value] }.flatten]

      # Scss file was deleted
      expect(mapped["5-file"]).to eq(nil)

      expect(mapped["0-header"]).to eq("I AM UPDATED")
      expect(mapped["1-scss"]).to eq(scss_data)

      expect(theme.settings.length).to eq(1)
      expect(theme.settings[:integer_setting].value).to eq(32)

      expect(remote.remote_updated_at).to eq_time(time)
      expect(remote.about_url).to eq("https://newsite.com/about")

      # It should be able to remove old colors as well
      File.write(
        "#{initial_repo}/about.json",
        about_json(love_color: "BABABA", tertiary_low_color: "", color_scheme_name: "Amazing 2"),
      )
      `cd #{initial_repo} && git commit -am "update"`

      remote.update_from_remote
      theme.reload

      scheme_count = ColorScheme.where(theme_id: theme.id).count
      expect(scheme_count).to eq(1)

      scheme = ColorScheme.find_by(theme_id: theme.id)
      expect(scheme.colors.find_by(name: "tertiary_low_color")).to eq(nil)
    end

    it "can update themes with overwritten history" do
      theme = RemoteTheme.import_theme(initial_repo_url)
      remote = theme.remote_theme

      old_version = `cd #{initial_repo} && git rev-parse HEAD`.strip
      expect(theme.name).to eq("awesome theme")
      expect(remote.remote_url).to eq(initial_repo_url)
      expect(remote.local_version).to eq(old_version)
      expect(remote.remote_version).to eq(old_version)

      `cd #{initial_repo} && git commit --amend -m "amended commit"`
      new_version = `cd #{initial_repo} && git rev-parse HEAD`.strip

      # make sure that the amended commit does not exist anymore
      `cd #{initial_repo} && git reflog expire --all --expire=now`
      `cd #{initial_repo} && git prune`

      remote.update_remote_version
      expect(remote.reload.local_version).to eq(old_version)
      expect(remote.reload.remote_version).to eq(new_version)
      expect(remote.reload.commits_behind).to eq(-1)
    end

    it "runs only new migrations when updating a theme" do
      add_to_git_repo(initial_repo, "settings.yaml" => <<~YAML)
        first_integer_setting: 1
        second_integer_setting: 2
      YAML
      add_to_git_repo(initial_repo, "migrations/settings/0002-another-migration.js" => <<~JS)
        export default function migrate(settings) {
          settings.set("first_integer_setting", 101);
          return settings;
        }
      JS

      theme = RemoteTheme.import_theme(initial_repo_url)

      expect(theme.get_setting(:first_integer_setting)).to eq(101)
      expect(theme.get_setting(:second_integer_setting)).to eq(2)

      theme.update_setting(:first_integer_setting, 110)

      add_to_git_repo(initial_repo, "migrations/settings/0003-yet-another-migration.js" => <<~JS)
        export default function migrate(settings) {
          settings.set("second_integer_setting", 201);
          return settings;
        }
      JS

      theme.remote_theme.update_from_remote
      theme.reload

      expect(theme.get_setting(:first_integer_setting)).to eq(110)
      expect(theme.get_setting(:second_integer_setting)).to eq(201)
    end

    it "fails if theme has too many files" do
      stub_const(RemoteTheme, "MAX_THEME_FILE_COUNT", 1) do
        expect { RemoteTheme.import_theme(initial_repo_url) }.to raise_error(
          RemoteTheme::ImportError,
          I18n.t("themes.import_error.too_many_files", count: 17, limit: 1),
        )
      end
    end

    it "fails if files are too large" do
      stub_const(RemoteTheme, "MAX_ASSET_FILE_SIZE", 1.byte) do
        expect { RemoteTheme.import_theme(initial_repo_url) }.to raise_error(
          RemoteTheme::ImportError,
          I18n.t(
            "themes.import_error.asset_too_big",
            filename: "about.json",
            limit: ActiveSupport::NumberHelper.number_to_human_size(1),
          ),
        )
      end
    end

    it "fails if theme is too large" do
      stub_const(RemoteTheme, "MAX_THEME_SIZE", 1.byte) do
        expect { RemoteTheme.import_theme(initial_repo_url) }.to raise_error(
          RemoteTheme::ImportError,
          I18n.t(
            "themes.import_error.theme_too_big",
            limit: ActiveSupport::NumberHelper.number_to_human_size(1),
          ),
        )
      end
    end

    describe "screenshots" do
      it "fails if any of the provided screenshots is not an accepted file type" do
        stub_const(ThemeScreenshotsHandler, "THEME_SCREENSHOT_ALLOWED_FILE_TYPES", [".bmp"]) do
          expect { RemoteTheme.import_theme(initial_repo_url) }.to raise_error(
            RemoteTheme::ImportError,
            I18n.t(
              "themes.import_error.screenshot_invalid_type",
              file_name: "light.jpeg",
              accepted_formats: ".bmp",
            ),
          )
        end
      end

      it "fails if any of the provided screenshots is too big" do
        stub_const(ThemeScreenshotsHandler, "MAX_THEME_SCREENSHOT_FILE_SIZE", 1.byte) do
          expect { RemoteTheme.import_theme(initial_repo_url) }.to raise_error(
            RemoteTheme::ImportError,
            I18n.t(
              "themes.import_error.screenshot_invalid_size",
              file_name: "light.jpeg",
              max_size: "1 Bytes",
            ),
          )
        end
      end

      it "fails if any of the provided screenshots has dimensions that are too big" do
        FastImage
          .expects(:size)
          .with { |arg| arg.match(%r{/screenshots/light\.jpeg}) }
          .returns([512, 512])
        stub_const(ThemeScreenshotsHandler, "MAX_THEME_SCREENSHOT_DIMENSIONS", [1, 1]) do
          expect { RemoteTheme.import_theme(initial_repo_url) }.to raise_error(
            RemoteTheme::ImportError,
            I18n.t(
              "themes.import_error.screenshot_invalid_dimensions",
              file_name: "light.jpeg",
              width: 512,
              height: 512,
              max_width: 1,
              max_height: 1,
            ),
          )
        end
      end

      it "creates uploads and associated theme fields for all theme screenshots" do
        theme = RemoteTheme.import_theme(initial_repo_url)

        screenshot_1 = theme.theme_fields.find_by(name: "screenshot_light")
        screenshot_2 = theme.theme_fields.find_by(name: "screenshot_dark")

        expect(screenshot_1).to be_present
        expect(screenshot_1.type_id).to eq(ThemeField.types[:theme_screenshot_upload_var])
        expect(screenshot_2).to be_present
        expect(screenshot_2.type_id).to eq(ThemeField.types[:theme_screenshot_upload_var])
        expect(screenshot_1.upload).to be_present
        expect(screenshot_2.upload).to be_present

        expect(UploadReference.exists?(target: screenshot_1)).to eq(true)
        expect(UploadReference.exists?(target: screenshot_2)).to eq(true)

        expect(screenshot_1.upload.original_filename).to eq("light.jpeg")
        expect(screenshot_2.upload.original_filename).to eq("dark.jpeg")
      end
    end

    describe "theme site settings" do
      it "creates theme site settings defined in about.json" do
        add_to_git_repo(
          initial_repo,
          "about.json" =>
            JSON
              .parse(about_json)
              .merge("theme_site_settings" => { "enable_welcome_banner" => false })
              .to_json,
        )

        theme = RemoteTheme.import_theme(initial_repo_url)
        expect(theme.theme_site_settings.count).to eq(1)
        expect(theme.theme_site_settings.first.name).to eq("enable_welcome_banner")
        expect(theme.theme_site_settings.first.value).to eq("f")
        expect(theme.theme_site_settings.first.data_type).to eq(SiteSetting.types[:bool])
      end

      it "does not remove theme site settings that are no longer in about.json" do
        add_to_git_repo(
          initial_repo,
          "about.json" =>
            JSON
              .parse(about_json)
              .merge(
                "theme_site_settings" => {
                  "enable_welcome_banner" => false,
                  "search_experience" => "search_field",
                },
              )
              .to_json,
        )

        theme = RemoteTheme.import_theme(initial_repo_url)
        expect(theme.theme_site_settings.count).to eq(2)

        add_to_git_repo(
          initial_repo,
          "about.json" =>
            JSON
              .parse(about_json)
              .merge("theme_site_settings" => { "enable_welcome_banner" => false })
              .to_json,
        )

        theme.remote_theme.update_from_remote
        theme.reload

        expect(theme.theme_site_settings.count).to eq(2)
        expect(theme.theme_site_settings.first.name).to eq("enable_welcome_banner")
        expect(theme.theme_site_settings.first.value).to eq("f")
        expect(theme.theme_site_settings.second.name).to eq("search_experience")
        expect(theme.theme_site_settings.second.value).to eq("search_field")
      end

      it "ignores non-themeable site settings" do
        add_to_git_repo(
          initial_repo,
          "about.json" =>
            JSON
              .parse(about_json)
              .merge("theme_site_settings" => { "min_admin_password_length" => 20 })
              .to_json,
        )

        theme = nil

        theme = RemoteTheme.import_theme(initial_repo_url)

        expect(theme.theme_site_settings.count).to eq(0)
      end

      # TODO (martin) Hard to test this without a better example...we don't have any
      # theme site settings that are an enum with > 2 values.
      xit "does not override user modified theme site settings" do
        add_to_git_repo(
          initial_repo,
          "about.json" =>
            JSON
              .parse(about_json)
              .merge("theme_site_settings" => { "search_experience" => "search_field" })
              .to_json,
        )

        theme = RemoteTheme.import_theme(initial_repo_url)
        expect(theme.theme_site_settings.first.value).to eq("search_field")

        theme.theme_site_settings.first.update!(value: "search_icon")

        add_to_git_repo(
          initial_repo,
          "about.json" =>
            JSON
              .parse(about_json)
              .merge("theme_site_settings" => { "search_experience" => "search_field" })
              .to_json,
        )

        theme.remote_theme.update_from_remote
        theme.reload

        expect(theme.theme_site_settings.first.value).to eq("search_icon")
      end

      it "does not update the existing theme site setting" do
        add_to_git_repo(
          initial_repo,
          "about.json" =>
            JSON
              .parse(about_json)
              .merge("theme_site_settings" => { "search_experience" => "search_field" })
              .to_json,
        )

        theme = RemoteTheme.import_theme(initial_repo_url)
        expect(theme.theme_site_settings.first.name).to eq("search_experience")
        expect(theme.theme_site_settings.first.value).to eq("search_field")

        add_to_git_repo(
          initial_repo,
          "about.json" =>
            JSON
              .parse(about_json)
              .merge("theme_site_settings" => { "search_experience" => "search_icon" })
              .to_json,
        )

        theme.remote_theme.update_from_remote
        theme.reload

        expect(theme.theme_site_settings.first.value).to eq("search_field")
      end

      it "makes sure to refresh the site setting theme site setting cache so we have full data there for each theme" do
        add_to_git_repo(
          initial_repo,
          "about.json" =>
            JSON
              .parse(about_json)
              .merge("theme_site_settings" => { "enable_welcome_banner" => false })
              .to_json,
        )
        theme = RemoteTheme.import_theme(initial_repo_url)

        expect(SiteSetting.theme_site_settings[theme.id][:enable_welcome_banner]).to eq(false)
        expect(SiteSetting.theme_site_settings[theme.id][:search_experience]).to eq("search_icon")
      end

      it "makes sure to set the theme site setting cache with defaults correctly when the theme has no theme_site_settings overrides defined" do
        theme = RemoteTheme.import_theme(initial_repo_url)

        expect(SiteSetting.theme_site_settings[theme.id][:enable_welcome_banner]).to eq(true)
        expect(SiteSetting.theme_site_settings[theme.id][:search_experience]).to eq("search_icon")
      end
    end
  end

  let(:github_repo) do
    RemoteTheme.create!(
      remote_url: "https://github.com/org/testtheme.git",
      local_version: "a2ec030e551fc8d8579790e1954876fe769fe40a",
      remote_version: "21122230dbfed804067849393c3332083ddd0c07",
      commits_behind: 2,
    )
  end

  let(:gitlab_repo) do
    RemoteTheme.create!(
      remote_url: "https://gitlab.com/org/repo.git",
      local_version: "a2ec030e551fc8d8579790e1954876fe769fe40a",
      remote_version: "21122230dbfed804067849393c3332083ddd0c07",
      commits_behind: 5,
    )
  end

  describe "#github_diff_link" do
    it "is blank for non-github repos" do
      expect(gitlab_repo.github_diff_link).to be_blank
    end

    it "returns URL for comparing between local_version and remote_version" do
      expect(github_repo.github_diff_link).to eq(
        "https://github.com/org/testtheme/compare/#{github_repo.local_version}...#{github_repo.remote_version}",
      )
    end

    it "is blank when theme is up-to-date" do
      github_repo.update!(local_version: github_repo.remote_version, commits_behind: 0)
      expect(github_repo.reload.github_diff_link).to be_blank
    end
  end

  describe ".extract_theme_info" do
    let(:importer) { mock }

    let(:theme_info) do
      {
        "name" => "My Theme",
        "about_url" => "https://example.com/about",
        "license_url" => "https://example.com/license",
      }
    end

    it "raises an error if about.json is too big" do
      importer.stubs(:file_size).with("about.json").returns(100_000_000)

      expect { RemoteTheme.extract_theme_info(importer) }.to raise_error(
        RemoteTheme::ImportError,
        I18n.t(
          "themes.import_error.about_json_too_big",
          limit:
            ActiveSupport::NumberHelper.number_to_human_size((RemoteTheme::MAX_METADATA_FILE_SIZE)),
        ),
      )
    end

    it "raises an error if about.json is invalid" do
      importer.stubs(:file_size).with("about.json").returns(123)
      importer.stubs(:[]).with("about.json").returns("{")

      expect { RemoteTheme.extract_theme_info(importer) }.to raise_error(
        RemoteTheme::ImportError,
        I18n.t("themes.import_error.about_json"),
      )
    end

    it "returns extracted theme info" do
      importer.stubs(:file_size).with("about.json").returns(123)
      importer.stubs(:[]).with("about.json").returns(theme_info.to_json)

      expect(RemoteTheme.extract_theme_info(importer)).to eq(theme_info)
    end
  end

  describe ".joined_remotes" do
    it "finds records that are associated with themes" do
      github_repo
      gitlab_repo
      expect(RemoteTheme.joined_remotes).to eq([])

      Fabricate(:theme, remote_theme: github_repo)
      expect(RemoteTheme.joined_remotes).to eq([github_repo])

      Fabricate(:theme, remote_theme: gitlab_repo)
      expect(RemoteTheme.joined_remotes).to contain_exactly(github_repo, gitlab_repo)
    end
  end

  describe ".out_of_date_themes" do
    let(:remote) { RemoteTheme.create!(remote_url: "https://github.com/org/testtheme") }
    let!(:theme) { Fabricate(:theme, remote_theme: remote) }

    it "finds out of date themes" do
      remote.update!(local_version: "old version", remote_version: "new version", commits_behind: 2)
      expect(described_class.out_of_date_themes).to eq([[theme.name, theme.id]])

      remote.update!(local_version: "new version", commits_behind: 0)
      expect(described_class.out_of_date_themes).to eq([])
    end

    it "ignores disabled out of date themes" do
      remote.update!(local_version: "old version", remote_version: "new version", commits_behind: 2)
      theme.update!(enabled: false)
      expect(described_class.out_of_date_themes).to eq([])
    end
  end

  describe ".unreachable_themes" do
    let(:remote) do
      RemoteTheme.create!(
        remote_url: "https://github.com/org/testtheme",
        last_error_text: "can't contact this repo :(",
      )
    end
    let!(:theme) { Fabricate(:theme, remote_theme: remote) }

    it "finds out of date themes" do
      expect(described_class.unreachable_themes).to eq([[theme.name, theme.id]])

      remote.update!(last_error_text: nil)
      expect(described_class.unreachable_themes).to eq([])
    end
  end

  describe ".import_theme_from_directory" do
    let(:theme_dir) { "#{Rails.root}/spec/fixtures/themes/discourse-test-theme" }

    it "imports a theme from a directory" do
      theme = RemoteTheme.import_theme_from_directory(theme_dir)

      expect(theme.name).to eq("Header Icons")
      expect(theme.theme_fields.count).to eq(7)
    end
  end
end
