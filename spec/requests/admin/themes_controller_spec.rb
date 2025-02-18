# frozen_string_literal: true

RSpec.describe Admin::ThemesController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  let! :repo do
    setup_git_repo("about.json" => { name: "discourse-branch-header" }.to_json)
  end

  let! :repo_url do
    MockGitImporter.register("https://github.com/discourse/discourse-brand-header.git", repo)
  end

  around(:each) { |group| MockGitImporter.with_mock { group.run } }

  describe "#generate_key_pair" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "can generate key pairs" do
        post "/admin/themes/generate_key_pair.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["private_key"]).to eq(nil)
        expect(json["public_key"]).to include("ssh-rsa ")
        expect(Discourse.redis.get("ssh_key_#{json["public_key"]}")).not_to eq(nil)
      end
    end

    shared_examples "key pair generation not allowed" do
      it "prevents key pair generation with a 404 response" do
        post "/admin/themes/generate_key_pair.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "key pair generation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "key pair generation not allowed"
    end
  end

  describe "#upload_asset" do
    let(:file) { file_from_fixtures("fake.woff2", "woff2") }
    let(:filename) { File.basename(file) }
    let(:upload) { Rack::Test::UploadedFile.new(file) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "can create a theme upload" do
        post "/admin/themes/upload_asset.json", params: { file: upload }
        expect(response.status).to eq(201)

        upload = Upload.find_by(original_filename: filename)

        expect(upload.id).not_to be_nil
        expect(response.parsed_body["upload_id"]).to eq(upload.id)
      end

      context "when trying to upload an existing file" do
        let(:uploaded_file) { Upload.find_by(original_filename: filename) }
        let(:response_json) { response.parsed_body }

        it "reuses the original upload" do
          post "/admin/themes/upload_asset.json", params: { file: upload }
          expect(response.status).to eq(201)
          expect(response_json["upload_id"]).to eq(uploaded_file.id)
        end
      end
    end

    shared_examples "theme asset upload not allowed" do
      it "prevents theme asset upload with a 404 response" do
        expect do
          post "/admin/themes/upload_asset.json", params: { file: upload }
        end.not_to change { Upload.count }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme asset upload not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "theme asset upload not allowed"
    end
  end

  describe "#export" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "exports correctly" do
        theme = Fabricate(:theme, name: "Awesome Theme")
        theme.set_field(target: :common, name: :scss, value: ".body{color: black;}")
        theme.set_field(target: :desktop, name: :after_header, value: "<b>test</b>")
        theme.set_field(
          target: :extra_js,
          name: "discourse/controller/blah",
          value: 'console.log("test");',
        )
        theme.save!

        get "/admin/customize/themes/#{theme.id}/export"
        expect(response.status).to eq(200)

        # Save the output in a temp file (automatically cleaned up)
        file = Tempfile.new("archive.zip")
        file.write(response.body)
        file.rewind
        uploaded_file = Rack::Test::UploadedFile.new(file.path, "application/zip")

        # Now import it again
        expect do
          post "/admin/themes/import.json", params: { theme: uploaded_file }
          expect(response.status).to eq(201)
        end.to change { Theme.count }.by(1)

        json = response.parsed_body

        expect(json["theme"]["name"]).to eq("Awesome Theme")
        expect(json["theme"]["theme_fields"].length).to eq(3)
      end
    end

    shared_examples "theme export not allowed" do
      it "prevents theme export with a 404 response" do
        theme = Fabricate(:theme, name: "Awesome Theme")

        get "/admin/customize/themes/#{theme.id}/export"

        expect(response.status).to eq(404)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme export not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "theme export not allowed"
    end
  end

  describe "#import" do
    let(:theme_json_file) do
      Rack::Test::UploadedFile.new(
        file_from_fixtures("sam-s-simple-theme.dcstyle.json", "json"),
        "application/json",
      )
    end

    let(:theme_archive) do
      Rack::Test::UploadedFile.new(
        file_from_fixtures("discourse-test-theme.zip", "themes"),
        "application/zip",
      )
    end

    let(:image) { file_from_fixtures("logo.png") }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      context "when theme allowlist mode is enabled" do
        before do
          global_setting :allowed_theme_repos,
                         "https://github.com/discourse/discourse-brand-header.git"
        end

        it "allows allowlisted imports" do
          expect(Theme.allowed_remote_theme_ids.length).to eq(0)

          post "/admin/themes/import.json",
               params: {
                 remote: "    https://github.com/discourse/discourse-brand-header.git       ",
               }

          expect(Theme.allowed_remote_theme_ids.length).to eq(1)
          expect(response.status).to eq(201)
        end

        it "prevents adding disallowed themes" do
          RemoteTheme.stubs(:import_theme)
          remote = "    https://bad.com/discourse/discourse-brand-header.git       "

          post "/admin/themes/import.json", params: { remote: remote }

          expect(response.status).to eq(403)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("themes.import_error.not_allowed_theme", { repo: remote.strip }),
          )
        end

        it "bans json file import" do
          post "/admin/themes/import.json", params: { theme: theme_json_file }
          expect(response.status).to eq(403)
        end
      end

      it "can import a theme from Git" do
        RemoteTheme.stubs(:import_theme).returns(Fabricate(:theme))
        post "/admin/themes/import.json",
             params: {
               remote: "    https://github.com/discourse/discourse-brand-header.git       ",
             }

        expect(response.status).to eq(201)
      end

      it "responds with suitable error message when a migration fails" do
        repo_path =
          setup_git_repo(
            "about.json" => { name: "test theme" }.to_json,
            "settings.yaml" => "boolean_setting: true",
            "migrations/settings/0001-some-migration.js" => <<~JS,
            export default function migrate(settings) {
              settings.set("unknown_setting", "dsad");
              return settings;
            }
          JS
          )

        repo_url = MockGitImporter.register("https://example.com/initial_repo.git", repo_path)

        post "/admin/themes/import.json", params: { remote: repo_url }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t(
            "themes.import_error.migrations.unknown_setting_returned_by_migration",
            name: "0001-some-migration",
            setting_name: "unknown_setting",
          ),
        )
      end

      it "fails to import with a failing status" do
        post "/admin/themes/import.json", params: { remote: "non-existent" }

        expect(response.status).to eq(422)
      end

      it "fails to import with a failing status" do
        post "/admin/themes/import.json", params: { remote: "https://#{"a" * 10_000}.com" }

        expect(response.status).to eq(422)
      end

      it "can lookup a private key by public key" do
        Discourse.redis.setex("ssh_key_abcdef", 1.hour, "rsa private key")

        post "/admin/themes/import.json",
             params: {
               remote: "    #{repo_url}       ",
               public_key: "abcdef",
             }

        expect(RemoteTheme.last.private_key).to eq("rsa private key")

        expect(response.status).to eq(201)
      end

      it "imports a theme" do
        post "/admin/themes/import.json", params: { theme: theme_json_file }
        expect(response.status).to eq(201)

        json = response.parsed_body

        expect(json["theme"]["name"]).to eq("Sam's Simple Theme")
        expect(json["theme"]["theme_fields"].length).to eq(2)
        expect(json["theme"]["auto_update"]).to eq(false)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end

      it "can fail if theme is not accessible" do
        post "/admin/themes/import.json",
             params: {
               remote: "git@github.com:discourse/discourse-inexistent-theme.git",
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(I18n.t("themes.import_error.git"))
      end

      it "can force install theme" do
        post "/admin/themes/import.json",
             params: {
               remote: "git@github.com:discourse/discourse-inexistent-theme.git",
               force: true,
             }

        expect(response.status).to eq(201)
        expect(response.parsed_body["theme"]["name"]).to eq("discourse-inexistent-theme")
      end

      it "fails to import with an error if uploads are not allowed" do
        SiteSetting.theme_authorized_extensions = "nothing"

        expect do
          post "/admin/themes/import.json", params: { theme: theme_archive }
        end.not_to change { Theme.count }

        expect(response.status).to eq(422)
      end

      it "imports a theme from an archive" do
        _existing_theme = Fabricate(:theme, name: "Header Icons")

        expect do post "/admin/themes/import.json", params: { theme: theme_archive } end.to change {
          Theme.count
        }.by(1)
        expect(response.status).to eq(201)
        json = response.parsed_body

        expect(json["theme"]["name"]).to eq("Header Icons")
        expect(json["theme"]["theme_fields"].length).to eq(6)
        expect(json["theme"]["auto_update"]).to eq(false)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end

      it "updates an existing theme from an archive by id" do
        # Used by theme CLI
        _existing_theme = Fabricate(:theme, name: "Header Icons")
        other_existing_theme = Fabricate(:theme, name: "Some other name")

        messages =
          MessageBus.track_publish("/file-change") do
            expect do
              post "/admin/themes/import.json",
                   params: {
                     bundle: theme_archive,
                     theme_id: other_existing_theme.id,
                   }

              expect(response.status).to eq(201)
            end.not_to change { Theme.count }
          end

        json = response.parsed_body

        # Ensure only one refresh message is sent.
        # More than 1 is wasteful, and can trigger unusual race conditions in the client
        # If this test fails, it probably means `theme.save` is being called twice - check any 'autosave' relations
        expect(messages.count).to eq(1)

        expect(json["theme"]["name"]).to eq("Some other name")
        expect(json["theme"]["id"]).to eq(other_existing_theme.id)
        expect(json["theme"]["theme_fields"].length).to eq(6)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end

      it "does not run migrations when importing a theme from an archive and `skip_settings_migrations` params is present" do
        other_existing_theme = Fabricate(:theme, name: "Some other name")

        post "/admin/themes/import.json",
             params: {
               bundle: theme_archive,
               theme_id: other_existing_theme.id,
               skip_migrations: true,
             }

        expect(response.status).to eq(201)
        expect(other_existing_theme.theme_settings_migrations.exists?).to eq(false)
      end

      it "creates a new theme when id specified as nil" do
        # Used by theme CLI
        existing_theme = Fabricate(:theme, name: "Header Icons")

        expect do
          post "/admin/themes/import.json", params: { bundle: theme_archive, theme_id: nil }
        end.to change { Theme.count }.by(1)
        expect(response.status).to eq(201)
        json = response.parsed_body

        expect(json["theme"]["name"]).to eq("Header Icons")
        expect(json["theme"]["id"]).not_to eq(existing_theme.id)
        expect(json["theme"]["theme_fields"].length).to eq(6)
        expect(json["theme"]["auto_update"]).to eq(false)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end
    end

    shared_examples "theme import not allowed" do
      it "prevents theme import with a 404 response" do
        post "/admin/themes/import.json", params: { theme: theme_json_file }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme import not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "theme import not allowed"
    end
  end

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "correctly returns themes" do
        ColorScheme.destroy_all
        Theme.destroy_all

        theme = Fabricate(:theme)
        theme.set_field(target: :common, name: :scss, value: ".body{color: black;}")
        theme.set_field(target: :desktop, name: :after_header, value: "<b>test</b>")

        theme.set_field(
          target: :migrations,
          name: "0001-some-migration",
          value: "export default function migrate(settings) { return settings; }",
        )

        theme.remote_theme =
          RemoteTheme.new(
            remote_url: "awesome.git",
            remote_version: "7",
            local_version: "8",
            remote_updated_at: Time.zone.now,
          )

        theme.save!

        # this will get serialized as well
        ColorScheme.create_from_base(name: "test", colors: [])

        get "/admin/themes.json"

        expect(response.status).to eq(200)

        json = response.parsed_body

        expect(json["extras"]["color_schemes"].length).to eq(1)
        theme_json = json["themes"].find { |t| t["id"] == theme.id }
        expect(theme_json["theme_fields"].length).to eq(3)

        expect(
          theme_json["theme_fields"].find { |theme_field| theme_field["target"] == "migrations" }[
            "migrated"
          ],
        ).to eq(false)

        expect(theme_json["remote_theme"]["remote_version"]).to eq("7")
      end
    end

    it "allows themes and components to be edited" do
      sign_in(admin)
      theme = Fabricate(:theme, name: "Awesome Theme")
      component = Fabricate(:theme, name: "Awesome component", component: true)

      get "/admin/customize/themes/#{theme.id}/common/scss/edit"
      expect(response.status).to eq(200)

      get "/admin/customize/components/#{component.id}/common/scss/edit"
      expect(response.status).to eq(200)
    end

    shared_examples "themes inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/themes.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "themes inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "themes inaccessible"
    end
  end

  describe "#create" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "creates a theme and theme fields" do
        post "/admin/themes.json",
             params: {
               theme: {
                 name: "my test name",
                 theme_fields: [name: "scss", target: "common", value: "body{color: red;}"],
               },
             }

        expect(response.status).to eq(201)

        json = response.parsed_body

        expect(json["theme"]["theme_fields"].length).to eq(1)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end

      it "can set a theme to default" do
        post "/admin/themes.json", params: { theme: { name: "my test name", default: "true" } }

        expect(response.status).to eq(201)

        json = response.parsed_body
        expect(json["theme"]["default"]).to eq(true)
      end
    end

    shared_examples "theme creation not allowed" do
      it "prevents creation with a 404 response" do
        expect do
          post "/admin/themes.json",
               params: {
                 theme: {
                   name: "my test name",
                   theme_fields: [name: "scss", target: "common", value: "body{color: red;}"],
                 },
               }
        end.not_to change { Theme.count }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "theme creation not allowed"
    end

    context "when theme allowlist mode is enabled" do
      before do
        global_setting :allowed_theme_repos, "  https://magic.com/repo.git, https://x.com/git"
      end

      it "prevents theme creation with 403 error" do
        expect do
          post "/admin/themes.json", params: { theme: { name: "my test name" } }
        end.not_to change { Theme.count }

        expect(response.status).to eq(404)
      end
    end
  end

  describe "#update" do
    let!(:theme) { Fabricate(:theme) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns the right response when an invalid id is given" do
        put "/admin/themes/99999.json"

        expect(response.status).to eq(400)
      end

      it "can change default theme" do
        SiteSetting.default_theme_id = -1

        put "/admin/themes/#{theme.id}.json", params: { id: theme.id, theme: { default: true } }

        expect(response.status).to eq(200)
        expect(SiteSetting.default_theme_id).to eq(theme.id)
      end

      it "can unset default theme" do
        SiteSetting.default_theme_id = theme.id

        put "/admin/themes/#{theme.id}.json", params: { theme: { default: false } }

        expect(response.status).to eq(200)
        expect(SiteSetting.default_theme_id).to eq(-1)
      end

      context "when theme allowlist mode is enabled" do
        before do
          global_setting :allowed_theme_repos, "  https://magic.com/repo.git, https://x.com/git"
        end

        it "unconditionally bans theme_fields from updating" do
          r = RemoteTheme.create!(remote_url: "https://magic.com/repo.git")
          theme.update!(remote_theme_id: r.id)

          put "/admin/themes/#{theme.id}.json",
              params: {
                theme: {
                  name: "my test name",
                  theme_fields: [
                    { name: "scss", target: "common", value: "" },
                    { name: "scss", target: "desktop", value: "body{color: blue;}" },
                  ],
                },
              }

          expect(response.status).to eq(403)
        end
      end

      it "updates a theme" do
        theme.set_field(target: :common, name: :scss, value: ".body{color: black;}")
        theme.save

        child_theme = Fabricate(:theme, component: true)

        upload =
          UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(
            Discourse.system_user.id,
          )

        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                child_theme_ids: [child_theme.id],
                name: "my test name",
                theme_fields: [
                  { name: "scss", target: "common", value: "" },
                  { name: "scss", target: "desktop", value: "body{color: blue;}" },
                  { name: "bob", target: "common", value: "", type_id: 2, upload_id: upload.id },
                ],
              },
            }

        expect(response.status).to eq(200)

        json = response.parsed_body

        expect(json["theme"]["theme_fields"].length).to eq(2)
        expect(json["theme"]["child_themes"].length).to eq(1)
        expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
      end

      it "prevents theme update when using ember css selectors" do
        child_theme = Fabricate(:theme, component: true)

        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                child_theme_ids: [child_theme.id],
                name: "my test name",
                theme_fields: [
                  { name: "scss", target: "common", value: "" },
                  { name: "scss", target: "desktop", value: ".ember-view{color: blue;}" },
                ],
              },
            }

        expect(response.status).to eq(200)

        json = response.parsed_body

        fields = json["theme"]["theme_fields"].sort { |a, b| a["value"] <=> b["value"] }
        expect(fields[0]["error"]).to eq(I18n.t("themes.ember_selector_error"))

        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                child_theme_ids: [child_theme.id],
                name: "my test name",
                theme_fields: [
                  { name: "scss", target: "common", value: "" },
                  { name: "scss", target: "desktop", value: "#ember392{color: blue;}" },
                ],
              },
            }

        expect(response.status).to eq(200)
        json = response.parsed_body

        fields = json["theme"]["theme_fields"].sort { |a, b| a["value"] <=> b["value"] }
        expect(fields[0]["error"]).to eq(I18n.t("themes.ember_selector_error"))
      end

      it "blocks remote theme fields from being locally edited" do
        r = RemoteTheme.create!(remote_url: "https://magic.com/repo.git")
        theme.update!(remote_theme_id: r.id)

        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                theme_fields: [
                  { name: "scss", target: "common", value: "" },
                  { name: "header", target: "common", value: "filename.jpg", upload_id: 4 },
                ],
              },
            }

        expect(response.status).to eq(403)
      end

      it "creates new theme fields" do
        expect(theme.theme_fields.count).to eq(0)

        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                theme_fields: [{ name: "scss", target: "common", value: "test" }],
              },
            }

        expect(response.status).to eq(200)
        theme.reload
        expect(theme.theme_fields.count).to eq(1)
        theme_field = theme.theme_fields.first
        expect(theme_field.name).to eq("scss")
        expect(theme_field.target_id).to eq(Theme.targets[:common])
        expect(theme_field.value).to eq("test")
      end

      it "doesn't create theme fields when they don't pass validation" do
        expect(theme.theme_fields.count).to eq(0)

        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                theme_fields: [
                  { name: "scss", target: "common", value: "Na " * 1024**2 + "Batman!" },
                ],
              },
            }

        expect(response.status).to eq(422)
        json = JSON.parse(response.body)
        expect(json["errors"].first).to include("Value is too long")
      end

      it "allows zip-imported theme fields to be locally edited" do
        r = RemoteTheme.create!(remote_url: "")
        theme.update!(remote_theme_id: r.id)

        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                theme_fields: [
                  { name: "scss", target: "common", value: "" },
                  { name: "header", target: "common", value: "filename.jpg", upload_id: 4 },
                ],
              },
            }

        expect(response.status).to eq(200)
      end

      it "updates a child theme" do
        child_theme = Fabricate(:theme, component: true)
        put "/admin/themes/#{child_theme.id}.json",
            params: {
              theme: {
                parent_theme_ids: [theme.id],
              },
            }
        expect(child_theme.parent_themes).to eq([theme])
      end

      it "can update translations" do
        theme.set_field(
          target: :translations,
          name: :en,
          value: { en: { somegroup: { somestring: "defaultstring" } } }.deep_stringify_keys.to_yaml,
        )
        theme.save!

        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                translations: {
                  "somegroup.somestring" => "overriddenstring",
                },
              },
            }

        # Response correct
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["theme"]["translations"][0]["value"]).to eq("overriddenstring")

        # Database correct
        theme.reload
        expect(theme.theme_translation_overrides.count).to eq(1)
        expect(theme.theme_translation_overrides.first.translation_key).to eq(
          "somegroup.somestring",
        )

        # Set back to default
        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                translations: {
                  "somegroup.somestring" => "defaultstring",
                },
              },
            }
        # Response correct
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["theme"]["translations"][0]["value"]).to eq("defaultstring")

        # Database correct
        theme.reload
        expect(theme.theme_translation_overrides.count).to eq(0)
      end

      it "checking for updates saves the remote_theme record" do
        theme.remote_theme =
          RemoteTheme.create!(
            remote_url: "http://discourse.org",
            remote_version: "a",
            local_version: "a",
            commits_behind: 0,
          )
        theme.save!
        ThemeStore::GitImporter.any_instance.stubs(:import!)
        ThemeStore::GitImporter.any_instance.stubs(:commits_since).returns(["b", 1])

        put "/admin/themes/#{theme.id}.json", params: { theme: { remote_check: true } }
        theme.reload
        expect(theme.remote_theme.remote_version).to eq("b")
        expect(theme.remote_theme.commits_behind).to eq(1)
      end

      it "can disable component" do
        child = Fabricate(:theme, component: true)

        put "/admin/themes/#{child.id}.json", params: { theme: { enabled: false } }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["theme"]["enabled"]).to eq(false)
        expect(
          UserHistory.where(
            context: child.id.to_s,
            action: UserHistory.actions[:disable_theme_component],
          ).size,
        ).to eq(1)
        expect(json["theme"]["disabled_by"]["id"]).to eq(admin.id)
      end

      it "enabling/disabling a component creates the correct staff action log" do
        child = Fabricate(:theme, component: true)
        UserHistory.destroy_all

        put "/admin/themes/#{child.id}.json", params: { theme: { enabled: false } }
        expect(response.status).to eq(200)

        expect(
          UserHistory.where(
            context: child.id.to_s,
            action: UserHistory.actions[:disable_theme_component],
          ).size,
        ).to eq(1)
        expect(
          UserHistory.where(
            context: child.id.to_s,
            action: UserHistory.actions[:enable_theme_component],
          ).size,
        ).to eq(0)

        put "/admin/themes/#{child.id}.json", params: { theme: { enabled: true } }
        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(
          UserHistory.where(
            context: child.id.to_s,
            action: UserHistory.actions[:disable_theme_component],
          ).size,
        ).to eq(1)
        expect(
          UserHistory.where(
            context: child.id.to_s,
            action: UserHistory.actions[:enable_theme_component],
          ).size,
        ).to eq(1)

        expect(json["theme"]["disabled_by"]).to eq(nil)
        expect(json["theme"]["enabled"]).to eq(true)
      end

      it "handles import errors on update" do
        theme.create_remote_theme!(remote_url: "https://example.com/repository")
        theme.save!

        # RemoteTheme is extensively tested, and setting up the test scaffold is a large overhead
        # So use a stub here to test the controller
        RemoteTheme
          .any_instance
          .stubs(:update_from_remote)
          .raises(RemoteTheme::ImportError.new("error message"))
        put "/admin/themes/#{theme.id}.json", params: { theme: { remote_update: true } }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq("error message")
      end

      it "returns the right error message" do
        theme.update!(component: true)

        put "/admin/themes/#{theme.id}.json", params: { theme: { default: true } }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include(
          I18n.t("themes.errors.component_no_default"),
        )
      end

      it "prevents converting the default theme to a component" do
        SiteSetting.default_theme_id = theme.id

        put "/admin/themes/#{theme.id}.json", params: { theme: { component: true } }

        # should this error message be localized? InvalidParameters :component
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include("component")
      end
    end

    shared_examples "theme update not allowed" do
      it "prevents updates with a 404 response" do
        SiteSetting.default_theme_id = -1

        put "/admin/themes/#{theme.id}.json", params: { id: theme.id, theme: { default: true } }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(SiteSetting.default_theme_id).not_to eq(theme.id)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "theme update not allowed"
    end
  end

  describe "#destroy" do
    let!(:theme) { Fabricate(:theme) }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns the right response when an invalid id is given" do
        delete "/admin/themes/9999.json"

        expect(response.status).to eq(404)
      end

      it "deletes the field's javascript cache" do
        theme.set_field(
          target: :common,
          name: :header,
          value: '<script>console.log("test")</script>',
        )
        theme.save!

        javascript_cache =
          theme
            .theme_fields
            .find_by(target_id: Theme.targets[:common], name: :header)
            .javascript_cache
        expect(javascript_cache).to_not eq(nil)

        delete "/admin/themes/#{theme.id}.json"

        expect(response.status).to eq(204)
        expect { theme.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { javascript_cache.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    shared_examples "theme deletion not allowed" do
      it "prevent deletion with a 404 response" do
        delete "/admin/themes/#{theme.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(theme.reload).to be_present
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme deletion not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "theme deletion not allowed"
    end
  end

  describe "#preview" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should return the right response when an invalid id is given" do
        get "/admin/themes/9999/preview.json"

        expect(response.status).to eq(400)
      end
    end

    shared_examples "theme previews inaccessible" do
      it "denies access with a 404 response" do
        theme = Fabricate(:theme)

        get "/admin/themes/#{theme.id}/preview.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme previews inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "theme previews inaccessible"
    end
  end

  describe "#update_single_setting" do
    fab!(:theme)

    before do
      theme.set_field(target: :settings, name: :yaml, value: "bg: red")
      theme.save!
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should update a theme setting" do
        put "/admin/themes/#{theme.id}/setting.json", params: { name: "bg", value: "green" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["bg"]).to eq("green")

        theme.reload
        expect(theme.cached_settings[:bg]).to eq("green")
        user_history = UserHistory.last

        expect(user_history.action).to eq(UserHistory.actions[:change_theme_setting])
      end

      it "should return the right error when value used to update a theme setting of `objects` typed is invalid" do
        theme.set_field(
          target: :settings,
          name: "yaml",
          value: File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml"),
        )

        theme.save!

        put "/admin/themes/#{theme.id}/setting.json",
            params: {
              name: "objects_setting",
              value: [
                { name: "new_section", links: [{ name: "a" * 21, url: "https://some.url.com" }] },
              ].to_json,
            }

        expect(response.status).to eq(422)

        expect(response.parsed_body["errors"]).to eq(
          ["The property at JSON Pointer '/0/links/0/name' must be at most 20 characters long."],
        )
      end

      it "should be able to update a theme setting of `objects` typed" do
        theme.set_field(
          target: :settings,
          name: "yaml",
          value: File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml"),
        )

        theme.save!

        put "/admin/themes/#{theme.id}/setting.json",
            params: {
              name: "objects_setting",
              value: [
                { name: "new_section", links: [{ name: "new link", url: "https://some.url.com" }] },
              ].to_json,
            }

        expect(response.status).to eq(200)

        expect(theme.settings[:objects_setting].value).to eq(
          [
            {
              "name" => "new_section",
              "links" => [{ "name" => "new link", "url" => "https://some.url.com" }],
            },
          ],
        )
      end

      it "should clear a theme setting" do
        put "/admin/themes/#{theme.id}/setting.json", params: { name: "bg" }
        theme.reload

        expect(response.status).to eq(200)
        expect(theme.cached_settings[:bg]).to eq("")
      end
    end

    shared_examples "theme update not allowed" do
      it "prevents updates with a 404 response" do
        put "/admin/themes/#{theme.id}/setting.json", params: { name: "bg", value: "green" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))

        theme.reload
        expect(theme.cached_settings[:bg]).to eq("red")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "theme update not allowed"
    end
  end

  describe "#update_translations" do
    fab!(:theme)

    before do
      theme.set_field(
        target: :translations,
        name: :en,
        value: { en: { group: { hello: "Hello there!" } } }.deep_stringify_keys.to_yaml,
      )
      theme.set_field(
        target: :translations,
        name: :fr,
        value: { fr: { group: { hello: "Bonjour Mes Amis!" } } }.deep_stringify_keys.to_yaml,
      )
      theme.save!
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should update a theme translation" do
        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                translations: {
                  "group.hello" => "Hello there! updated",
                },
              },
            }

        expect(response.status).to eq(200)
        theme.reload.translations.map { |t| expect(t.value).to eq("Hello there! updated") }
      end

      it "should update a theme translation with locale" do
        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                translations: {
                  "group.hello" => "Hello there! updated",
                },
                locale: "en",
              },
            }

        expect(response.status).to eq(200)
        theme.reload.translations.map { |t| expect(t.value).to eq("Hello there! updated") }
      end

      it "should fail update a theme translation when locale is wrong" do
        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                translations: {
                  "group.hello" => "Hello there! updated",
                },
                locale: "foo",
              },
            }

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("invalid_params", message: :locale),
        )
      end

      it "should update other locale and do not change current one" do
        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                translations: {
                  "group.hello" => "Bonjour Mes Amis! updated",
                },
                locale: "fr",
              },
            }

        expect(response.status).to eq(200)
        theme.reload.translations.map { |t| expect(t.value).to eq("Hello there!") }

        get "/admin/themes/#{theme.id}/translations/fr.json"
        translations = response.parsed_body["translations"]
        expect(translations.first["value"]).to eq("Bonjour Mes Amis! updated")
      end
    end

    shared_examples "theme update not allowed" do
      it "prevents updates with a 404 response" do
        put "/admin/themes/#{theme.id}.json",
            params: {
              theme: {
                translations: {
                  "group.hello" => "Bonjour Mes Amis! updated",
                },
                locale: "fr",
              },
            }
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "theme update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "theme update not allowed"
    end
  end

  describe "#get_translations" do
    fab!(:theme)

    before do
      theme.set_field(
        target: :translations,
        name: :en,
        value: { en: { group: { hello: "Hello there!" } } }.deep_stringify_keys.to_yaml,
      )
      theme.save!
    end

    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "get translations from theme" do
        get "/admin/themes/#{theme.id}/translations/en.json"
        translations = response.parsed_body["translations"]
        expect(translations.first["value"]).to eq("Hello there!")
      end

      it "fail if get translations from theme with wrong locale" do
        get "/admin/themes/#{theme.id}/translations/foo.json"
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("invalid_params", message: :locale),
        )
      end
    end

    shared_examples "get theme translations not allowed" do
      it "prevents updates with a 404 response" do
        get "/admin/themes/#{theme.id}/translations/en.json"
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "get theme translations not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "get theme translations not allowed"
    end
  end

  describe "#bulk_destroy" do
    fab!(:theme) { Fabricate(:theme, name: "Awesome Theme") }
    fab!(:theme_2) { Fabricate(:theme, name: "Another awesome Theme") }
    let(:theme_ids) { [theme.id, theme_2.id] }

    before { sign_in(admin) }

    it "destroys all selected the themes" do
      expect do
        delete "/admin/themes/bulk_destroy.json", params: { theme_ids: theme_ids }
      end.to change { Theme.count }.by(-2)
    end

    it "logs the theme destroy action for each theme" do
      StaffActionLogger.any_instance.expects(:log_theme_destroy).twice
      delete "/admin/themes/bulk_destroy.json", params: { theme_ids: theme_ids }
    end
  end

  describe "#objects_setting_metadata" do
    fab!(:theme)

    let(:theme_setting) do
      yaml = File.read("#{Rails.root}/spec/fixtures/theme_settings/objects_settings.yaml")
      theme.set_field(target: :settings, name: "yaml", value: yaml)
      theme.save!
      theme.settings
    end

    it "returns 404 if user is not an admin" do
      get "/admin/themes/#{theme.id}/objects_setting_metadata/objects_with_categories.json"

      expect(response.status).to eq(404)

      sign_in(user)

      get "/admin/themes/#{theme.id}/objects_setting_metadata/objects_with_categories.json"

      expect(response.status).to eq(404)

      sign_in(moderator)

      get "/admin/themes/#{theme.id}/objects_setting_metadata/objects_with_categories.json"

      expect(response.status).to eq(404)
    end

    context "when user is an admin" do
      before { sign_in(admin) }

      it "returns 400 if the `id` param is not the id of a valid theme" do
        get "/admin/themes/some_invalid_id/objects_setting_metadata/objects_with_categories.json"

        expect(response.status).to eq(400)
      end

      it "returns 400 if the `setting_name` param does not match a valid setting" do
        get "/admin/themes/#{theme.id}/objects_setting_metadata/some_invalid_setting_name.json"

        expect(response.status).to eq(400)
      end

      it "returns 200 with the right `property_descriptions` attributes" do
        theme.set_field(
          target: :translations,
          name: "en",
          value: File.read("#{Rails.root}/spec/fixtures/theme_locales/objects_settings/en.yaml"),
        )

        theme.save!

        theme_setting

        get "/admin/themes/#{theme.id}/objects_setting_metadata/objects_setting.json"

        expect(response.status).to eq(200)

        expect(response.parsed_body["property_descriptions"]).to eq(
          {
            "links.name.description" => "Name of the link",
            "links.name.label" => "Name",
            "links.url.description" => "URL of the link",
            "links.url.label" => "URL",
            "name.description" => "Section Name",
            "name.label" => "Name",
          },
        )
      end

      it "returns 200 with the right `categories` attribute for a theme setting with categories propertoes" do
        category_1 = Fabricate(:category)
        category_2 = Fabricate(:category)
        category_3 = Fabricate(:category)

        theme_setting[:objects_with_categories].value = [
          {
            "category_ids" => [category_1.id, category_2.id],
            "child_categories" => [{ "category_ids" => [category_3.id] }],
          },
        ]

        get "/admin/themes/#{theme.id}/objects_setting_metadata/objects_with_categories.json"

        expect(response.status).to eq(200)

        categories = response.parsed_body["categories"]

        expect(categories.keys.map(&:to_i)).to contain_exactly(
          category_1.id,
          category_2.id,
          category_3.id,
        )

        expect(categories[category_1.id.to_s]["name"]).to eq(category_1.name)
        expect(categories[category_2.id.to_s]["name"]).to eq(category_2.name)
        expect(categories[category_3.id.to_s]["name"]).to eq(category_3.name)
      end
    end
  end

  describe "#schema" do
    fab!(:theme)
    fab!(:theme_component) { Fabricate(:theme, component: true) }

    before { sign_in(admin) }

    it "returns 200 when customizing a theme's setting of objects type" do
      get "/admin/customize/themes/#{theme.id}/schema/some_setting_name"

      expect(response.status).to eq(200)
    end

    it "returns 200 when customizing a theme component's setting of objects type" do
      get "/admin/customize/components/#{theme_component.id}/schema/some_setting_name"

      expect(response.status).to eq(200)
    end
  end
end
