# frozen_string_literal: true

RSpec.describe ThemesInstallTask do
  fab!(:admin)

  describe ".new" do
    THEME_NAME = "awesome theme"

    def about_json(
      love_color: "FAFAFA",
      tertiary_low_color: "FFFFFF",
      color_scheme_name: "Amazing",
      about_url: "https://www.site.com/about",
      component: false
    )
      <<~JSON
        {
          "name": "#{THEME_NAME}",
          "about_url": "#{about_url}",
          "license_url": "https://www.site.com/license",
          "theme_version": "1.0",
          "minimum_discourse_version": "1.0.0",
          "assets": {
            "font": "assets/font.woff2"
          },
          "component": "#{component}",
          "color_schemes": {
            "#{color_scheme_name}": {
              "love": "#{love_color}",
              "tertiary-low": "#{tertiary_low_color}"
            }
          },
          "modifiers": {
            "serialize_topic_excerpts": true
          }
        }
      JSON
    end

    let :scss_data do
      "@font-face { font-family: magic; src: url($font)}; body {color: fuchsia;}"
    end

    let :theme_repo do
      setup_git_repo(
        "about.json" => about_json,
        "desktop/desktop.scss" => scss_data,
        "scss/oldpath.scss" => ".class2{color:blue}",
        "stylesheets/file.scss" => ".class1{color:red}",
        "stylesheets/empty.scss" => "",
        "javascripts/discourse/controllers/test.js.es6" => "console.log('test');",
        "common/header.html" => "I AM HEADER",
        "common/random.html" => "I AM SILLY",
        "common/embedded.scss" => "EMBED",
        "assets/font.woff2" => "FAKE FONT",
        "settings.yaml" => "boolean_setting: true",
        "locales/en.yml" => "sometranslations",
      )
    end

    let :theme_repo_url do
      MockGitImporter.register("https://example.com/theme_repo.git", theme_repo)
    end

    let :component_repo do
      setup_git_repo(
        "about.json" => about_json(component: true),
        "desktop/desktop.scss" => scss_data,
        "scss/oldpath.scss" => ".class2{color:blue}",
        "stylesheets/file.scss" => ".class1{color:red}",
        "stylesheets/empty.scss" => "",
        "javascripts/discourse/controllers/test.js.es6" => "console.log('test');",
        "common/header.html" => "I AM HEADER",
        "common/random.html" => "I AM SILLY",
        "common/embedded.scss" => "EMBED",
        "assets/font.woff2" => "FAKE FONT",
        "settings.yaml" => "boolean_setting: true",
        "locales/en.yml" => "sometranslations",
      )
    end

    let :component_repo_url do
      MockGitImporter.register("https://example.com/component_repo.git", component_repo)
    end

    after do
      `rm -fr #{theme_repo}`
      `rm -fr #{component_repo}`
    end

    it "gracefully fails" do
      ThemesInstallTask.install(nothing: "fail!")
      expect(Theme.where(name: "fail!").exists?).to eq(false)
    end

    before do
      FinalDestination.stubs(:resolve).with(theme_repo_url).returns(URI.parse(theme_repo_url))
      FinalDestination
        .stubs(:resolve)
        .with(component_repo_url)
        .returns(URI.parse(component_repo_url))
    end

    around(:each) { |group| MockGitImporter.with_mock { group.run } }

    describe "no options" do
      it "installs a theme" do
        ThemesInstallTask.install(some_theme: theme_repo_url)
        expect(Theme.where(name: THEME_NAME).exists?).to eq(true)
      end
    end

    describe "with options" do
      it "installs a theme from only a url" do
        ThemesInstallTask.install({ some_theme: { url: theme_repo_url } })
        expect(Theme.where(name: THEME_NAME).exists?).to eq(true)
      end

      it "does not set the theme to default if the key/value is not present" do
        ThemesInstallTask.install({ some_theme: { url: theme_repo_url } })
        theme = Theme.find_by(name: THEME_NAME)
        expect(theme.default?).to eq(false)
      end

      it "sets the theme to default if the key/value is true" do
        ThemesInstallTask.install({ some_theme: { url: theme_repo_url, default: true } })
        theme = Theme.find_by(name: THEME_NAME)
        expect(theme.default?).to eq(true)
      end

      it "installs theme components, but does not add them to themes" do
        ThemesInstallTask.install({ some_theme: { url: component_repo_url } })
        theme = Theme.find_by(name: THEME_NAME)
        expect(theme.component).to eq(true)
      end

      it 'adds component to all themes if "add_to_all_themes" is true' do
        ThemesInstallTask.install(
          { some_theme: { url: component_repo_url, add_to_all_themes: true } },
        )
        theme = Theme.find_by(name: THEME_NAME)
        Theme
          .where(component: false)
          .each do |parent_theme|
            expect(
              ChildTheme.find_by(parent_theme_id: parent_theme.id, child_theme_id: theme.id).nil?,
            ).to eq(false)
          end
      end

      it "updates theme fields" do
        ThemesInstallTask.install({ some_theme: component_repo_url })
        theme = Theme.find_by(name: THEME_NAME)
        remote = theme.remote_theme

        scss = "body { background-color: black; }"

        expect(theme.theme_fields.find_by(name: "scss", value: scss)).to be_nil

        File.write("#{component_repo}/common/common.scss", scss)

        `cd #{component_repo} && git add common/common.scss`
        `cd #{component_repo} && git commit -am "update"`

        remote.update_remote_version
        expect(remote.commits_behind).to eq(1)
        expect(remote.remote_version).to eq(`cd #{component_repo} && git rev-parse HEAD`.strip)

        ThemesInstallTask.install({ some_theme: component_repo_url })

        expect(theme.theme_fields.find_by(name: "scss", value: scss)).not_to be_nil
        expect(remote.reload.commits_behind).to eq(0)
      end
    end
  end

  describe "#theme_exists?" do
    it "can use https or ssh and find the same repo" do
      remote_theme =
        RemoteTheme.create!(
          remote_url: "https://github.com/org/testtheme.git",
          local_version: "a2ec030e551fc8d8579790e1954876fe769fe40a",
          remote_version: "21122230dbfed804067849393c3332083ddd0c07",
          commits_behind: 2,
        )
      Fabricate(:theme, remote_theme: remote_theme, user: admin)

      # https
      installer = ThemesInstallTask.new({ url: "https://github.com/org/testtheme" })
      expect(installer.theme_exists?).to eq(true)

      # ssh
      installer = ThemesInstallTask.new({ url: "git@github.com:org/testtheme.git" })
      expect(installer.theme_exists?).to eq(true)
    end
  end
end
