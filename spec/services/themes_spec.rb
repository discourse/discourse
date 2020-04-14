# frozen_string_literal: true

require 'rails_helper'

describe ThemesInstallTask do

  before do
    Discourse::Application.load_tasks
  end

  describe '.new' do
    def setup_git_repo(files)
      dir = Dir.tmpdir
      repo_dir = "#{dir}/#{SecureRandom.hex}"
      `mkdir #{repo_dir}`
      `cd #{repo_dir} && git init . `
      `cd #{repo_dir} && git config user.email 'someone@cool.com'`
      `cd #{repo_dir} && git config user.name 'The Cool One'`
      `cd #{repo_dir} && git config commit.gpgsign 'false'`
      files.each do |name, data|
        FileUtils.mkdir_p(Pathname.new("#{repo_dir}/#{name}").dirname)
        File.write("#{repo_dir}/#{name}", data)
        `cd #{repo_dir} && git add #{name}`
      end
      `cd #{repo_dir} && git commit -am 'first commit'`
      repo_dir
    end

    THEME_NAME = "awesome theme"

    def about_json(love_color: "FAFAFA", tertiary_low_color: "FFFFFF", color_scheme_name: "Amazing", about_url: "https://www.site.com/about", component: false)
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
      "@font-face { font-family: magic; src: url($font)}; body {color: $color; content: $name;}"
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
        "locales/en.yml" => "sometranslations"
      )
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
        "locales/en.yml" => "sometranslations"
      )
    end

    after do
      `rm -fr #{theme_repo}`
      `rm -fr #{component_repo}`
    end

    it 'gracefully fails' do
      ThemesInstallTask.install("nothing": "fail!")
      expect(Theme.where(name: "fail!").exists?).to eq(false)
    end

    describe "no options" do
      it 'installs a theme' do
        ThemesInstallTask.install("some_theme": theme_repo)
        expect(Theme.where(name: THEME_NAME).exists?).to eq(true)
      end
    end

    describe "with options" do
      it 'installs a theme from only a url' do
        ThemesInstallTask.install({ "some_theme": { "url": theme_repo } })
        expect(Theme.where(name: THEME_NAME).exists?).to eq(true)
      end

      it 'does not set the theme to default if the key/value is not present' do
        ThemesInstallTask.install({ "some_theme": { "url": theme_repo } })
        theme = Theme.find_by(name: THEME_NAME)
        expect(theme.default?).to eq(false)
      end

      it 'sets the theme to default if the key/value is true' do
        ThemesInstallTask.install({ "some_theme": { "url": theme_repo, default: true } })
        theme = Theme.find_by(name: THEME_NAME)
        expect(theme.default?).to eq(true)
      end

      it 'installs theme components, but does not add them to themes' do
        ThemesInstallTask.install({ "some_theme": { "url": component_repo } })
        theme = Theme.find_by(name: THEME_NAME)
        expect(theme.component).to eq(true)
      end

      it 'adds component to all themes if "add_to_all_themes" is true' do
        ThemesInstallTask.install({ "some_theme": { "url": component_repo, add_to_all_themes: true } })
        theme = Theme.find_by(name: THEME_NAME)
        Theme.where(component: false).each do |parent_theme|
          expect(ChildTheme.find_by(parent_theme_id: parent_theme.id, child_theme_id: theme.id).nil?).to eq(false)
        end
      end
    end
  end
  describe '#theme_exists?' do
    it 'can use https or ssh and find the same repo' do
      remote_theme = RemoteTheme.create!(
        remote_url: "https://github.com/org/testtheme.git",
        local_version: "a2ec030e551fc8d8579790e1954876fe769fe40a",
        remote_version: "21122230dbfed804067849393c3332083ddd0c07",
        commits_behind: 2
      )
      Fabricate(:theme, remote_theme: remote_theme)

      # https
      installer = ThemesInstallTask.new({ "url": "https://github.com/org/testtheme" })
      expect(installer.theme_exists?).to eq(true)

      # ssh
      installer = ThemesInstallTask.new({ "url": "git@github.com:org/testtheme.git" })
      expect(installer.theme_exists?).to eq(true)
    end
  end
end
