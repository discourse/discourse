# frozen_string_literal: true

RSpec.describe "tasks/themes" do
  describe "themes:export_theme_bundle" do
    let!(:theme) do
      Fabricate(:theme, name: "My Test Theme", component: false).tap do |t|
        t.set_field(target: :settings, name: "yaml", value: <<~YAML)
          parent_color:
            type: string
            default: "red"
        YAML
        t.save!
      end
    end

    let!(:component) do
      Fabricate(:theme, name: "My Component", component: true).tap do |c|
        c.set_field(target: :settings, name: "yaml", value: <<~YAML)
          show_header:
            type: bool
            default: true
          header_text:
            type: string
            default: "Hello"
        YAML
        c.save!
      end
    end

    before do
      theme.child_themes << component
      theme.update_setting(:parent_color, "blue")
      component.update_setting(:header_text, "Custom Title")
    end

    it "exports a zip with theme, components, and manifest" do
      Dir.mktmpdir do |output_dir|
        output_path = File.join(output_dir, "bundle.zip")

        capture_stdout do
          invoke_rake_task("themes:export_theme_bundle", theme.id.to_s, output_path)
        end

        expect(File.exist?(output_path)).to eq(true)

        # Extract and verify
        Dir.mktmpdir do |extract_dir|
          Zip::File.open(output_path) do |zip|
            zip.each do |entry|
              dest = File.join(extract_dir, entry.name)
              if entry.directory?
                FileUtils.mkdir_p(dest)
              else
                FileUtils.mkdir_p(File.dirname(dest))
                File.binwrite(dest, entry.get_input_stream.read)
              end
            end
          end

          # Manifest exists
          manifest_path = File.join(extract_dir, "manifest.json")
          expect(File.exist?(manifest_path)).to eq(true)

          manifest = JSON.parse(File.read(manifest_path))

          # Theme info
          expect(manifest["name"]).to eq("My Test Theme")
          expect(manifest["theme_id"]).to eq(theme.id)
          expect(manifest["exported_at"]).to be_present

          # Parent settings — only non-default
          expect(manifest["settings"]).to eq({ "parent_color" => "blue" })

          # Components
          expect(manifest["components"].length).to eq(1)
          comp_manifest = manifest["components"].first
          expect(comp_manifest["name"]).to eq("My Component")
          expect(comp_manifest["settings"]).to eq({ "header_text" => "Custom Title" })

          # Theme directory exists with about.json
          expect(File.exist?(File.join(extract_dir, "theme", "about.json"))).to eq(true)

          # Component directory exists
          comp_dir = File.join(extract_dir, "components", comp_manifest["dir"])
          expect(Dir.exist?(comp_dir)).to eq(true)
          expect(File.exist?(File.join(comp_dir, "about.json"))).to eq(true)
        end
      end
    end

    it "finds theme by name case-insensitively" do
      Dir.mktmpdir do |output_dir|
        output_path = File.join(output_dir, "bundle.zip")

        capture_stdout do
          invoke_rake_task("themes:export_theme_bundle", "my test theme", output_path)
        end

        expect(File.exist?(output_path)).to eq(true)
      end
    end

    it "only includes non-default settings in the manifest" do
      Dir.mktmpdir do |output_dir|
        output_path = File.join(output_dir, "bundle.zip")

        capture_stdout do
          invoke_rake_task("themes:export_theme_bundle", theme.id.to_s, output_path)
        end

        Dir.mktmpdir do |extract_dir|
          Zip::File.open(output_path) do |zip|
            zip.each do |entry|
              dest = File.join(extract_dir, entry.name)
              if entry.directory?
                FileUtils.mkdir_p(dest)
              else
                FileUtils.mkdir_p(File.dirname(dest))
                File.binwrite(dest, entry.get_input_stream.read)
              end
            end
          end

          manifest = JSON.parse(File.read(File.join(extract_dir, "manifest.json")))

          # parent_color was changed to "blue", should be present
          expect(manifest["settings"]).to have_key("parent_color")

          # Component: header_text was changed, show_header was not
          comp = manifest["components"].first
          expect(comp["settings"]).to have_key("header_text")
          expect(comp["settings"]).not_to have_key("show_header")
        end
      end
    end
  end

  describe "themes:import_theme_bundle" do
    it "imports a theme bundle with components and settings" do
      # First create and export a theme
      theme =
        Fabricate(:theme, name: "Export Me", component: false).tap do |t|
          t.set_field(target: :settings, name: "yaml", value: <<~YAML)
            bg_color:
              type: string
              default: "white"
          YAML
          t.save!
        end

      component =
        Fabricate(:theme, name: "Export Component", component: true).tap do |c|
          c.set_field(target: :settings, name: "yaml", value: <<~YAML)
            enabled:
              type: bool
              default: false
          YAML
          c.save!
        end

      theme.child_themes << component
      theme.update_setting(:bg_color, "black")
      component.update_setting(:enabled, true)

      Dir.mktmpdir do |output_dir|
        output_path = File.join(output_dir, "bundle.zip")

        capture_stdout do
          invoke_rake_task("themes:export_theme_bundle", theme.id.to_s, output_path)
        end

        # Now destroy originals and import
        component.destroy!
        theme.destroy!

        output = capture_stdout { invoke_rake_task("themes:import_theme_bundle", output_path) }

        expect(output).to include("Bundle imported successfully!")

        # Verify imported theme exists
        imported_theme = Theme.find_by(name: "Export Me")
        expect(imported_theme).to be_present
        expect(imported_theme.settings[:bg_color].value).to eq("black")

        # Verify component is attached
        expect(imported_theme.child_themes.count).to eq(1)
        imported_comp = imported_theme.child_themes.first
        expect(imported_comp.name).to eq("Export Component")
        expect(imported_comp.settings[:enabled].value).to eq(true)
      end
    end
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

      expect(theme.theme_fields.count).to eq(3)
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

      expect(theme.theme_fields.count).to eq(3)
      expect(theme.theme_fields.where(name: "header").first.value).to eq("I AM A HEADER")
      expect(theme.theme_settings_migrations.count).to eq(0)
      expect(theme.remote_theme.commits_behind).to eq(0)
      expect(theme.remote_theme.remote_version).to eq(original_remote_version)
      expect(theme.remote_theme.local_version).to eq(original_local_version)
    end
  end
end
