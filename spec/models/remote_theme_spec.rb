# frozen_string_literal: true

RSpec.describe RemoteTheme do
  describe "#import_remote" do
    def about_json(
      love_color: "FAFAFA",
      tertiary_low_color: "FFFFFF",
      color_scheme_name: "Amazing",
      about_url: "https://www.site.com/about"
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
            "serialize_topic_excerpts": true
          }
        }
      JSON
    end

    let :scss_data do
      "@font-face { font-family: magic; src: url($font)}; body {color: $color; content: $name;}"
    end

    let :initial_repo do
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
        "settings.yaml" => "boolean_setting: true",
        "locales/en.yml" => "sometranslations",
      )
    end

    let :initial_repo_url do
      MockGitImporter.register("https://example.com/initial_repo.git", initial_repo)
    end

    after { `rm -fr #{initial_repo}` }

    around(:each) { |group| MockGitImporter.with_mock { group.run } }

    it "can correctly import a remote theme" do
      time = Time.new("2000")
      freeze_time time

      @theme = RemoteTheme.import_theme(initial_repo_url)
      remote = @theme.remote_theme

      expect(@theme.name).to eq("awesome theme")
      expect(remote.remote_url).to eq(initial_repo_url)
      expect(remote.remote_version).to eq(`cd #{initial_repo} && git rev-parse HEAD`.strip)
      expect(remote.local_version).to eq(`cd #{initial_repo} && git rev-parse HEAD`.strip)

      expect(remote.about_url).to eq("https://www.site.com/about")
      expect(remote.license_url).to eq("https://www.site.com/license")
      expect(remote.theme_version).to eq("1.0")
      expect(remote.minimum_discourse_version).to eq("1.0.0")

      expect(@theme.theme_modifier_set.serialize_topic_excerpts).to eq(true)

      expect(@theme.theme_fields.length).to eq(11)

      mapped = Hash[*@theme.theme_fields.map { |f| ["#{f.target_id}-#{f.name}", f.value] }.flatten]

      expect(mapped["0-header"]).to eq("I AM HEADER")
      expect(mapped["1-scss"]).to eq(scss_data)
      expect(mapped["0-embedded_scss"]).to eq("EMBED")
      expect(mapped["0-color_definitions"]).to eq(":root{--color-var: red}")

      expect(mapped["0-font"]).to eq("")

      expect(mapped["3-yaml"]).to eq("boolean_setting: true")

      expect(mapped["4-en"]).to eq("sometranslations")
      expect(mapped["7-acceptance/theme-test.js"]).to eq("assert.ok(true);")

      expect(mapped.length).to eq(11)

      expect(@theme.settings.length).to eq(1)
      expect(@theme.settings.first.value).to eq(true)

      expect(remote.remote_updated_at).to eq_time(time)

      scheme = ColorScheme.find_by(theme_id: @theme.id)
      expect(scheme.name).to eq("Amazing")
      expect(scheme.colors.find_by(name: "love").hex).to eq("fafafa")
      expect(scheme.colors.find_by(name: "tertiary-low").hex).to eq("ffffff")

      expect(@theme.color_scheme_id).to eq(scheme.id)
      @theme.update(color_scheme_id: nil)

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
      @theme.save!
      @theme.reload

      scheme = ColorScheme.find_by(theme_id: @theme.id)
      expect(scheme.name).to eq("Amazing")
      expect(scheme.colors.find_by(name: "love").hex).to eq("eaeaea")
      expect(@theme.color_scheme_id).to eq(nil) # Should only be set on first import

      mapped = Hash[*@theme.theme_fields.map { |f| ["#{f.target_id}-#{f.name}", f.value] }.flatten]

      # Scss file was deleted
      expect(mapped["5-file"]).to eq(nil)

      expect(mapped["0-header"]).to eq("I AM UPDATED")
      expect(mapped["1-scss"]).to eq(scss_data)

      expect(@theme.settings.length).to eq(1)
      expect(@theme.settings.first.value).to eq(32)

      expect(remote.remote_updated_at).to eq_time(time)
      expect(remote.about_url).to eq("https://newsite.com/about")

      # It should be able to remove old colors as well
      File.write(
        "#{initial_repo}/about.json",
        about_json(love_color: "BABABA", tertiary_low_color: "", color_scheme_name: "Amazing 2"),
      )
      `cd #{initial_repo} && git commit -am "update"`

      remote.update_from_remote
      @theme.save
      @theme.reload

      scheme_count = ColorScheme.where(theme_id: @theme.id).count
      expect(scheme_count).to eq(1)

      scheme = ColorScheme.find_by(theme_id: @theme.id)
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
end
