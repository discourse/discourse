# frozen_string_literal: true

require 'rails_helper'
require_dependency 'theme_serializer'

describe Admin::ThemesController do
  fab!(:admin) { Fabricate(:admin) }

  it "is a subclass of AdminController" do
    expect(Admin::UsersController < Admin::AdminController).to eq(true)
  end

  before do
    sign_in(admin)
  end

  describe '#generate_key_pair' do
    it 'can generate key pairs' do
      post "/admin/themes/generate_key_pair.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["private_key"]).to include("RSA PRIVATE KEY")
      expect(json["public_key"]).to include("ssh-rsa ")
    end
  end

  describe '#upload_asset' do
    let(:upload) do
      Rack::Test::UploadedFile.new(file_from_fixtures("fake.woff2", "woff2"))
    end

    it 'can create a theme upload' do
      post "/admin/themes/upload_asset.json", params: { file: upload }
      expect(response.status).to eq(201)

      upload = Upload.find_by(original_filename: "fake.woff2")

      expect(upload.id).not_to be_nil
      expect(JSON.parse(response.body)["upload_id"]).to eq(upload.id)
    end
  end

  describe '#export' do
    it "exports correctly" do
      theme = Fabricate(:theme, name: "Awesome Theme")
      theme.set_field(target: :common, name: :scss, value: '.body{color: black;}')
      theme.set_field(target: :desktop, name: :after_header, value: '<b>test</b>')
      theme.save!

      get "/admin/customize/themes/#{theme.id}/export"
      expect(response.status).to eq(200)

      # Save the output in a temp file (automatically cleaned up)
      file = Tempfile.new('archive.tar.zip')
      file.write(response.body)
      file.rewind
      uploaded_file = Rack::Test::UploadedFile.new(file.path, "application/zip")

      # Now import it again
      expect do
        post "/admin/themes/import.json", params: { theme: uploaded_file }
        expect(response.status).to eq(201)
      end.to change { Theme.count }.by (1)

      json = ::JSON.parse(response.body)

      expect(json["theme"]["name"]).to eq("Awesome Theme")
      expect(json["theme"]["theme_fields"].length).to eq(2)
    end
  end

  describe '#import' do
    let(:theme_json_file) do
      Rack::Test::UploadedFile.new(file_from_fixtures("sam-s-simple-theme.dcstyle.json", "json"), "application/json")
    end

    let(:theme_archive) do
      Rack::Test::UploadedFile.new(file_from_fixtures("discourse-test-theme.tar.gz", "themes"), "application/x-gzip")
    end

    let(:image) do
      file_from_fixtures("logo.png")
    end

    it 'can import a theme from Git' do
      RemoteTheme.stubs(:import_theme)
      post "/admin/themes/import.json", params: {
        remote: '    https://github.com/discourse/discourse-brand-header       '
      }

      expect(response.status).to eq(201)
    end

    it 'imports a theme' do
      post "/admin/themes/import.json", params: { theme: theme_json_file }
      expect(response.status).to eq(201)

      json = ::JSON.parse(response.body)

      expect(json["theme"]["name"]).to eq("Sam's Simple Theme")
      expect(json["theme"]["theme_fields"].length).to eq(2)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end

    it 'imports a theme from an archive' do
      existing_theme = Fabricate(:theme, name: "Header Icons")

      expect do
        post "/admin/themes/import.json", params: { theme: theme_archive }
      end.to change { Theme.count }.by (1)
      expect(response.status).to eq(201)
      json = ::JSON.parse(response.body)

      expect(json["theme"]["name"]).to eq("Header Icons")
      expect(json["theme"]["theme_fields"].length).to eq(5)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end

    it 'updates an existing theme from an archive by name' do
      # Old theme CLI method, remove Jan 2020
      existing_theme = Fabricate(:theme, name: "Header Icons")

      expect do
        post "/admin/themes/import.json", params: { bundle: theme_archive }
      end.to change { Theme.count }.by (0)
      expect(response.status).to eq(201)
      json = ::JSON.parse(response.body)

      expect(json["theme"]["name"]).to eq("Header Icons")
      expect(json["theme"]["theme_fields"].length).to eq(5)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end

    it 'updates an existing theme from an archive by id' do
      # Used by theme CLI
      existing_theme = Fabricate(:theme, name: "Header Icons")
      other_existing_theme = Fabricate(:theme, name: "Some other name")

      messages = MessageBus.track_publish do
        expect do
          post "/admin/themes/import.json", params: { bundle: theme_archive, theme_id: other_existing_theme.id }
        end.to change { Theme.count }.by (0)
      end
      expect(response.status).to eq(201)
      json = ::JSON.parse(response.body)

      # Ensure only one refresh message is sent.
      # More than 1 is wasteful, and can trigger unusual race conditions in the client
      # If this test fails, it probably means `theme.save` is being called twice - check any 'autosave' relations
      file_change_messages = messages.filter { |m| m[:channel] == "/file-change" }
      expect(file_change_messages.count).to eq(1)

      expect(json["theme"]["name"]).to eq("Some other name")
      expect(json["theme"]["id"]).to eq(other_existing_theme.id)
      expect(json["theme"]["theme_fields"].length).to eq(5)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end

    it 'creates a new theme when id specified as nil' do
      # Used by theme CLI
      existing_theme = Fabricate(:theme, name: "Header Icons")

      expect do
        post "/admin/themes/import.json", params: { bundle: theme_archive, theme_id: nil }
      end.to change { Theme.count }.by (1)
      expect(response.status).to eq(201)
      json = ::JSON.parse(response.body)

      expect(json["theme"]["name"]).to eq("Header Icons")
      expect(json["theme"]["id"]).not_to eq(existing_theme.id)
      expect(json["theme"]["theme_fields"].length).to eq(5)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end
  end

  describe '#index' do
    it 'correctly returns themes' do
      ColorScheme.destroy_all
      Theme.destroy_all

      theme = Fabricate(:theme)
      theme.set_field(target: :common, name: :scss, value: '.body{color: black;}')
      theme.set_field(target: :desktop, name: :after_header, value: '<b>test</b>')

      theme.remote_theme = RemoteTheme.new(
        remote_url: 'awesome.git',
        remote_version: '7',
        local_version: '8',
        remote_updated_at: Time.zone.now
      )

      theme.save!

      # this will get serialized as well
      ColorScheme.create_from_base(name: "test", colors: [])

      get "/admin/themes.json"

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)

      expect(json["extras"]["color_schemes"].length).to eq(2)
      theme_json = json["themes"].find { |t| t["id"] == theme.id }
      expect(theme_json["theme_fields"].length).to eq(2)
      expect(theme_json["remote_theme"]["remote_version"]).to eq("7")
    end
  end

  describe '#create' do
    it 'creates a theme' do
      post "/admin/themes.json", params: {
        theme: {
          name: 'my test name',
          theme_fields: [name: 'scss', target: 'common', value: 'body{color: red;}']
        }
      }

      expect(response.status).to eq(201)

      json = ::JSON.parse(response.body)

      expect(json["theme"]["theme_fields"].length).to eq(1)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end
  end

  describe '#update' do
    let!(:theme) { Fabricate(:theme) }

    it 'returns the right response when an invalid id is given' do
      put "/admin/themes/99999.json"

      expect(response.status).to eq(400)
    end

    it 'can change default theme' do
      SiteSetting.default_theme_id = -1

      put "/admin/themes/#{theme.id}.json", params: {
        id: theme.id, theme: { default: true }
      }

      expect(response.status).to eq(200)
      expect(SiteSetting.default_theme_id).to eq(theme.id)
    end

    it 'can unset default theme' do
      SiteSetting.default_theme_id = theme.id

      put "/admin/themes/#{theme.id}.json", params: {
        theme: { default: false }
      }

      expect(response.status).to eq(200)
      expect(SiteSetting.default_theme_id).to eq(-1)
    end

    it 'updates a theme' do
      theme.set_field(target: :common, name: :scss, value: '.body{color: black;}')
      theme.save

      child_theme = Fabricate(:theme, component: true)

      upload = Fabricate(:upload)

      put "/admin/themes/#{theme.id}.json", params: {
        theme: {
          child_theme_ids: [child_theme.id],
          name: 'my test name',
          theme_fields: [
            { name: 'scss', target: 'common', value: '' },
            { name: 'scss', target: 'desktop', value: 'body{color: blue;}' },
            { name: 'bob', target: 'common', value: '', type_id: 2, upload_id: upload.id },
          ]
        }
      }

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)

      fields = json["theme"]["theme_fields"].sort { |a, b| a["value"] <=> b["value"] }

      expect(fields[0]["value"]).to eq('')
      expect(fields[0]["upload_id"]).to eq(upload.id)
      expect(fields[1]["value"]).to eq('body{color: blue;}')
      expect(fields.length).to eq(2)
      expect(json["theme"]["child_themes"].length).to eq(1)
      expect(UserHistory.where(action: UserHistory.actions[:change_theme]).count).to eq(1)
    end

    it 'can update translations' do
      theme.set_field(target: :translations, name: :en, value: { en: { somegroup: { somestring: "defaultstring" } } }.deep_stringify_keys.to_yaml)
      theme.save!

      put "/admin/themes/#{theme.id}.json", params: {
        theme: {
          translations: {
            "somegroup.somestring" => "overridenstring"
          }
        }
      }

      # Response correct
      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["theme"]["translations"][0]["value"]).to eq("overridenstring")

      # Database correct
      theme.reload
      expect(theme.theme_translation_overrides.count).to eq(1)
      expect(theme.theme_translation_overrides.first.translation_key).to eq("somegroup.somestring")

      # Set back to default
      put "/admin/themes/#{theme.id}.json", params: {
        theme: {
          translations: {
            "somegroup.somestring" => "defaultstring"
          }
        }
      }
      # Response correct
      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["theme"]["translations"][0]["value"]).to eq("defaultstring")

      # Database correct
      theme.reload
      expect(theme.theme_translation_overrides.count).to eq(0)
    end

    it 'checking for updates saves the remote_theme record' do
      theme.remote_theme = RemoteTheme.create!(remote_url: "http://discourse.org", remote_version: "a", local_version: "a", commits_behind: 0)
      theme.save!
      ThemeStore::GitImporter.any_instance.stubs(:import!)
      ThemeStore::GitImporter.any_instance.stubs(:commits_since).returns(["b", 1])

      put "/admin/themes/#{theme.id}.json", params: {
        theme: {
          remote_check: true
        }
      }
      theme.reload
      expect(theme.remote_theme.remote_version).to eq("b")
      expect(theme.remote_theme.commits_behind).to eq(1)
    end

    it 'can disable component' do
      child = Fabricate(:theme, component: true)

      put "/admin/themes/#{child.id}.json", params: {
        theme: {
          enabled: false
        }
      }
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["theme"]["enabled"]).to eq(false)
      expect(UserHistory.where(
        context: child.id.to_s,
        action: UserHistory.actions[:disable_theme_component]
      ).size).to eq(1)
      expect(json["theme"]["disabled_by"]["id"]).to eq(admin.id)
    end

    it "enabling/disabling a component creates the correct staff action log" do
      child = Fabricate(:theme, component: true)
      UserHistory.destroy_all

      put "/admin/themes/#{child.id}.json", params: {
        theme: {
          enabled: false
        }
      }
      expect(response.status).to eq(200)

      expect(UserHistory.where(
        context: child.id.to_s,
        action: UserHistory.actions[:disable_theme_component]
      ).size).to eq(1)
      expect(UserHistory.where(
        context: child.id.to_s,
        action: UserHistory.actions[:enable_theme_component]
      ).size).to eq(0)

      put "/admin/themes/#{child.id}.json", params: {
        theme: {
          enabled: true
        }
      }
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)

      expect(UserHistory.where(
        context: child.id.to_s,
        action: UserHistory.actions[:disable_theme_component]
      ).size).to eq(1)
      expect(UserHistory.where(
        context: child.id.to_s,
        action: UserHistory.actions[:enable_theme_component]
      ).size).to eq(1)

      expect(json["theme"]["disabled_by"]).to eq(nil)
      expect(json["theme"]["enabled"]).to eq(true)
    end

    it 'handles import errors on update' do
      theme.create_remote_theme!(remote_url: "https://example.com/repository")
      theme.save!

      # RemoteTheme is extensively tested, and setting up the test scaffold is a large overhead
      # So use a stub here to test the controller
      RemoteTheme.any_instance.stubs(:update_from_remote).raises(RemoteTheme::ImportError.new("error message"))
      put "/admin/themes/#{theme.id}.json", params: {
        theme: { remote_update: true }
      }
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)["errors"].first).to eq("error message")
    end

    it 'returns the right error message' do
      theme.update!(component: true)

      put "/admin/themes/#{theme.id}.json", params: {
        theme: { default: true }
      }

      expect(response.status).to eq(400)
      expect(JSON.parse(response.body)["errors"].first).to include(I18n.t("themes.errors.component_no_default"))
    end
  end

  describe '#destroy' do
    let!(:theme) { Fabricate(:theme) }

    it 'returns the right response when an invalid id is given' do
      delete "/admin/themes/9999.json"

      expect(response.status).to eq(400)
    end

    it "deletes the field's javascript cache" do
      theme.set_field(target: :common, name: :header, value: '<script>console.log("test")</script>')
      theme.save!

      javascript_cache = theme.theme_fields.find_by(target_id: Theme.targets[:common], name: :header).javascript_cache
      expect(javascript_cache).to_not eq(nil)

      delete "/admin/themes/#{theme.id}.json"

      expect(response.status).to eq(204)
      expect { theme.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { javascript_cache.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#preview' do
    it "should return the right response when an invalid id is given" do
      get "/admin/themes/9999/preview.json"

      expect(response.status).to eq(400)
    end
  end

  describe '#diff_local_changes' do
    let(:theme) { Fabricate(:theme) }

    it "should return empty for a default theme" do
      get "/admin/themes/#{theme.id}/diff_local_changes.json"
      expect(response.body).to eq("{}")
    end
  end

  describe '#update_single_setting' do
    let(:theme) { Fabricate(:theme) }

    before do
      theme.set_field(target: :settings, name: :yaml, value: "bg: red")
      theme.save!
    end

    it "should update a theme setting" do
      put "/admin/themes/#{theme.id}/setting.json", params: {
        name: "bg",
        value: "green"
      }

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)["bg"]).to eq("green")

      theme.reload
      expect(theme.included_settings[:bg]).to eq("green")
      user_history = UserHistory.last

      expect(user_history.action).to eq(
        UserHistory.actions[:change_theme_setting]
      )
    end

    it "should clear a theme setting" do
      put "/admin/themes/#{theme.id}/setting.json", params: { name: "bg" }
      theme.reload

      expect(response.status).to eq(200)
      expect(theme.included_settings[:bg]).to eq("")
    end
  end
end
