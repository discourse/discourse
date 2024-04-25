# frozen_string_literal: true

RSpec.describe "tasks/themes" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
  end

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

      setup_git_repo("about.json" => about_json, "common/header.html" => "I AM A HEADER")
    end

    let(:initial_repo_url) do
      MockGitImporter.register("https://example.com/initial_repo.git", initial_repo)
    end

    let!(:theme) { RemoteTheme.import_theme(initial_repo_url) }

    around(:each) { |group| MockGitImporter.with_mock { group.run } }

    after { `rm -fr #{initial_repo}` }

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

      capture_stderr { capture_stdout { Rake::Task["themes:update"].invoke } }

      theme.reload

      expect(theme.theme_fields.count).to eq(1)
      expect(theme.theme_fields.where(name: "header").first.value).to eq("I AM A HEADER")
      expect(theme.theme_settings_migrations.count).to eq(0)
      expect(theme.remote_theme.commits_behind).to eq(0)
      expect(theme.remote_theme.remote_version).to eq(original_remote_version)
      expect(theme.remote_theme.local_version).to eq(original_local_version)
    end
  end
end
