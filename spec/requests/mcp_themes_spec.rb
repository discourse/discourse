# frozen_string_literal: true

require "zip"
require "rubygems/package"

describe "MCP theme administration" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:scope_group, :group)
  fab!(:theme)

  before { SiteSetting.mcp_server_enabled = true }

  def authorize(actor = admin, scopes: %w[mcp:themes:read mcp:themes:write])
    scope_group.add(actor)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group: scope_group, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Theme test",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    grant =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: actor,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: scopes,
      )
    @token = McpOauthAccessToken.issue!(authorization: grant)
  end

  def call_tool(name, arguments = {}, request_env = {})
    McpPrimitive.find_or_create_by!(kind: "tool", identifier: name) do |primitive|
      primitive.enabled = true
    end
    post "/mcp",
         env: request_env,
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name:,
             arguments:,
           },
         }.to_json,
         headers: {
           "HTTP_AUTHORIZATION" => "Bearer #{@token}",
           "CONTENT_TYPE" => "application/json",
           "HTTP_ACCEPT" => "application/json, text/event-stream",
           "HTTP_MCP_PROTOCOL_VERSION" => DiscourseMcp::LEGACY_PROTOCOL_VERSION,
         }
  end

  def operations
    {
      "discourse_list_themes" => {
      },
      "discourse_delete_theme" => {
        theme_id: theme.id,
        expected_name: theme.name,
        confirm: true,
      },
      "discourse_install_theme" => {
        remote_url: "https://example.com/theme.git",
        confirm_external_code: true,
        confirm_run_migrations: true,
      },
      "discourse_sync_remote_theme" => {
        theme_id: theme.id,
        action: "check",
      },
      "discourse_upload_theme_asset" => {
        filename: "test.txt",
        file_data: Base64.strict_encode64("test"),
      },
      "discourse_update_theme_setting" => {
        theme_id: theme.id,
        name: "enabled",
        operation: "set",
        value: true,
      },
      "discourse_update_theme_translations" => {
        theme_id: theme.id,
        expected_name: theme.name,
        locale: "en",
        translations: {
          greeting: "Hello",
        },
      },
    }
  end

  def archive_data(files)
    buffer =
      Zip::OutputStream.write_buffer do |archive|
        files.each do |name, contents|
          archive.put_next_entry(name)
          archive.write(contents)
        end
      end
    Base64.strict_encode64(buffer.string)
  end

  def gzip_archive_data(files)
    tar = StringIO.new
    Gem::Package::TarWriter.new(tar) do |writer|
      files.each do |name, contents|
        writer.add_file_simple(name, 0o644, contents.bytesize) { |file| file.write(contents) }
      end
    end
    buffer = StringIO.new
    gzip = Zlib::GzipWriter.new(buffer)
    gzip.write(tar.string)
    gzip.close
    Base64.strict_encode64(buffer.string)
  end

  it "defers theme imports, repository operations and asset uploads" do
    authorize
    requests = {
      "discourse_install_theme" => {
        filename: "theme.zip",
        archive_data: archive_data("about.json" => { name: "Deferred theme" }.to_json),
        confirm_external_code: true,
      },
      "discourse_sync_remote_theme" => {
        theme_id: theme.id,
        action: "check",
      },
      "discourse_upload_theme_asset" => {
        filename: "logo.png",
        file_data: Base64.strict_encode64(File.binread(file_from_fixtures("logo.png"))),
      },
    }
    requests.each do |name, arguments|
      io = StringIO.new
      Scheduler::Defer.capture_later do
        call_tool(name, arguments, { "rack.hijack" => -> { io } })
        expect(response.status).to eq(418)
        expect(io.string).to be_empty
      end
      expect(io.string).to start_with("HTTP/1.1 200")
      result = JSON.parse(io.string.split("\r\n\r\n", 2).last).fetch("result")
      expect(result["isError"]).to eq(name == "discourse_sync_remote_theme"), "#{name}: #{result}"
    end
  end

  it "refuses to queue a disabled tool or a call without its scope" do
    authorize
    primitive =
      McpPrimitive.create!(kind: "tool", identifier: "discourse_install_theme", enabled: false)
    arguments = {
      remote_url: "https://example.com/theme.git",
      confirm_external_code: true,
      confirm_run_migrations: true,
    }
    io = StringIO.new
    Scheduler::Defer.capture_later do
      call_tool("discourse_install_theme", arguments, { "rack.hijack" => -> { io } })
      expect(response.status).to eq(400)
      expect(io.string).to be_empty
    end
    primitive.update!(enabled: true)
    authorize(admin, scopes: [])
    Scheduler::Defer.capture_later do
      call_tool("discourse_install_theme", arguments, { "rack.hijack" => -> { io } })
      expect(response.status).to eq(403)
      expect(io.string).to be_empty
    end
  end

  it "imports archives with uppercase extensions and tar-gzip aliases" do
    authorize
    files = { "about.json" => { name: "Archive 猫" }.to_json }
    {
      "theme.ZIP" => archive_data(files),
      "theme.tgz" => gzip_archive_data(files),
    }.each do |filename, data|
      call_tool(
        "discourse_install_theme",
        { filename:, archive_data: data, confirm_external_code: true },
      )
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(false)
      expect(
        Theme.find(response.parsed_body.dig("result", "structuredContent", "theme", "id")).name,
      ).to eq("Archive 猫")
    end
  end

  it "returns a tool error for corrupt archives without creating a theme" do
    authorize
    {
      "theme.zip" => "not an archive",
      "theme.tar.gz" => "not an archive",
      "theme.tgz" => Zlib.gzip("not a tar archive"),
    }.each do |filename, data|
      expect do
        call_tool(
          "discourse_install_theme",
          { filename:, archive_data: Base64.strict_encode64(data), confirm_external_code: true },
        )
      end.not_to change(Theme, :count)
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      error = filename == "theme.tgz" ? "about_json" : "unpack_failed"
      expect(response.body).to include(I18n.t("themes.import_error.#{error}"))
    end
  end

  it "returns a compact result after installing a theme with large source files" do
    authorize
    files = { "about.json" => { name: "Large theme" }.to_json }
    %w[head_tag header body_tag].each { |name| files["common/#{name}.html"] = "x" * 900_000 }
    call_tool(
      "discourse_install_theme",
      { filename: "theme.zip", archive_data: archive_data(files), confirm_external_code: true },
    )
    expect(response.status).to eq(200)
    result = response.parsed_body.dig("result", "structuredContent", "theme")
    expect(Theme.find(result["id"]).name).to eq("Large theme")
    expect(result).not_to have_key("theme_fields")
    expect(response.body.bytesize).to be < 10_000
  end

  it "returns a tool error when an archive exceeds the entry limit" do
    authorize
    data =
      archive_data(
        "about.json" => { name: "Too many entries" }.to_json,
        "common/header.html" => "hello",
      )
    stub_const(Compression::Zip, :MAX_ZIP_ENTRIES, 1) do
      expect do
        call_tool(
          "discourse_install_theme",
          { filename: "theme.zip", archive_data: data, confirm_external_code: true },
        )
      end.not_to change(Theme, :count)
    end
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
  end

  it "rejects invalid object-setting shapes without changing the saved value" do
    theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
      links:
        type: objects
        default:
          - name: Home
        schema:
          name: link
          properties:
            name:
              type: string
    YAML
    theme.save!
    authorize
    [true, 123, "{}", "[1]"].each do |value|
      call_tool(
        "discourse_update_theme_setting",
        { theme_id: theme.id, name: "links", operation: "set", value: },
      )
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(theme.reload.cached_settings[:links]).to eq([{ "name" => "Home" }])
    end
  end

  it "updates keys and restores defaults in the requested translation locale" do
    theme.set_field(target: :translations, name: "en", value: "en:\n  greeting: Hello\n")
    theme.set_field(
      target: :translations,
      name: "fr",
      value: "fr:\n  greeting: Bonjour\n  french_only: Français\n",
    )
    theme.save!
    authorize
    arguments = { theme_id: theme.id, expected_name: theme.name, locale: "fr" }
    call_tool(
      "discourse_update_theme_translations",
      arguments.merge(translations: { french_only: "猫", greeting: "Salut" }),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(
      theme
        .theme_translation_overrides
        .find_by!(locale: "fr", translation_key: "french_only")
        .value,
    ).to eq("猫")
    call_tool(
      "discourse_update_theme_translations",
      arguments.merge(translations: { greeting: "Bonjour" }),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(
      theme.theme_translation_overrides.where(locale: "fr", translation_key: "greeting"),
    ).not_to exist
  end

  it "requires admin permission even with both theme scopes" do
    [user, moderator].each do |actor|
      authorize(actor)
      operations.each do |name, arguments|
        call_tool(name, arguments)
        expect(response.status).to eq(403), "#{name}: #{response.body}"
      end
    end
    expect(theme.reload).to be_persisted
  end

  it "requires theme scopes even for an administrator" do
    authorize(scopes: [])
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(403), "#{name}: #{response.body}"
      expect(response.headers["WWW-Authenticate"]).to include("insufficient_scope")
    end
  end

  it "lists bounded summaries without source or private repository credentials" do
    remote = Fabricate(:remote_theme, private_key: "PRIVATE KEY")
    theme.update!(remote_theme: remote)
    authorize
    call_tool("discourse_list_themes", { limit: 1 })
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent", "themes").length).to eq(1)
    expect(response.body).not_to include(remote.private_key, "theme_fields")
  end

  it "requires the current name and confirmation before deleting a theme" do
    authorize
    call_tool(
      "discourse_delete_theme",
      { theme_id: theme.id, expected_name: "wrong", confirm: true },
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(Theme.exists?(theme.id)).to eq(true)
    call_tool(
      "discourse_delete_theme",
      { theme_id: theme.id, expected_name: theme.name, confirm: true },
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(Theme.exists?(theme.id)).to eq(false)
    expect(UserHistory.where(action: UserHistory.actions[:delete_theme]).count).to eq(1)
  end

  it "refuses to delete the default theme" do
    theme.set_default!
    authorize
    call_tool(
      "discourse_delete_theme",
      { theme_id: theme.id, expected_name: theme.name, confirm: true },
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(Theme.exists?(theme.id)).to eq(true)
  end

  it "changes a declared setting using theme validation and can revert it" do
    theme.set_field(
      target: :settings,
      name: "yaml",
      value: "heading:\n  default: Welcome\n  max: 20\n",
    )
    theme.save!
    authorize
    call_tool(
      "discourse_update_theme_setting",
      { theme_id: theme.id, name: "heading", operation: "set", value: "猫" },
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(theme.reload.cached_settings[:heading]).to eq("猫")
    call_tool(
      "discourse_update_theme_setting",
      { theme_id: theme.id, name: "heading", operation: "revert", confirm: true },
    )
    expect(theme.reload.cached_settings[:heading]).to eq("Welcome")
    expect(response.parsed_body.dig("result", "structuredContent", "value")).to eq("Welcome")
  end

  it "restores a boolean setting whose default is true" do
    theme.set_field(target: :settings, name: "yaml", value: "show_heading: true\n")
    theme.save!
    authorize
    call_tool(
      "discourse_update_theme_setting",
      { theme_id: theme.id, name: "show_heading", operation: "set", value: false },
    )
    expect(theme.reload.cached_settings[:show_heading]).to eq(false)
    expect(response.parsed_body.dig("result", "structuredContent", "value")).to eq(false)

    call_tool(
      "discourse_update_theme_setting",
      { theme_id: theme.id, name: "show_heading", operation: "revert", confirm: true },
    )
    expect(theme.reload.cached_settings[:show_heading]).to eq(true)
    expect(response.parsed_body.dig("result", "structuredContent", "value")).to eq(true)
  end

  it "rejects an excessive page size before listing themes" do
    authorize
    call_tool("discourse_list_themes", { limit: 101 })
    expect(response.status).to eq(400)
    expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
  end

  it "rejects values that do not match the declared setting type" do
    theme.set_field(target: :settings, name: "yaml", value: "count: 3\nshow_heading: true\n")
    theme.save!
    authorize

    { "count" => true, "show_heading" => 1 }.each do |name, value|
      call_tool(
        "discourse_update_theme_setting",
        theme_id: theme.id,
        name:,
        operation: "set",
        value:,
      )
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    end
    expect(theme.reload.cached_settings).to include(count: 3, show_heading: true)

    call_tool(
      "discourse_update_theme_setting",
      theme_id: theme.id,
      name: "count",
      operation: "set",
      value: 4,
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(theme.reload.cached_settings[:count]).to eq(4)
  end

  it "updates system theme settings and translations with the required scope and permissions" do
    SystemThemesManager.sync_theme!("horizon")
    horizon = Theme.find(-2)
    authorize
    call_tool(
      "discourse_update_theme_setting",
      theme_id: horizon.id,
      name: "topic_card_high_context",
      operation: "set",
      value: false,
    )
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(horizon.reload.cached_settings[:topic_card_high_context]).to eq(false)

    call_tool(
      "discourse_update_theme_translations",
      theme_id: horizon.id,
      expected_name: horizon.name,
      locale: "en",
      translations: {
        "solved" => "Solved 猫",
      },
    )
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(horizon.reload.translations.find { |entry| entry.key == "solved" }.value).to eq(
      "Solved 猫",
    )
  end

  it "denies system theme updates without scope or administrator access" do
    SystemThemesManager.sync_theme!("horizon")
    horizon = Theme.find(-2)
    [[admin, []], [moderator, %w[mcp:themes:write]]].each do |actor, scopes|
      authorize(actor, scopes:)
      call_tool(
        "discourse_update_theme_setting",
        theme_id: horizon.id,
        name: "topic_card_high_context",
        operation: "set",
        value: false,
      )
      expect(response.status).to eq(403)
      call_tool(
        "discourse_update_theme_translations",
        theme_id: horizon.id,
        expected_name: horizon.name,
        locale: "en",
        translations: {
          "solved" => "Forbidden",
        },
      )
      expect(response.status).to eq(403)
    end
    expect(horizon.reload.cached_settings[:topic_card_high_context]).to eq(true)
    expect(horizon.reload.translations.find { |entry| entry.key == "solved" }.value).not_to eq(
      "Forbidden",
    )
  end

  it "sets object settings as arrays and restores their declared default" do
    theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
      links:
        type: objects
        default:
          - name: Home
        schema:
          name: link
          properties:
            name:
              type: string
              required: true
    YAML
    theme.save!
    authorize
    call_tool(
      "discourse_update_theme_setting",
      { theme_id: theme.id, name: "links", operation: "set", value: [{ name: "猫" }] },
    )
    expect(response.parsed_body.dig("result", "structuredContent", "value")).to eq(
      [{ "name" => "猫" }],
    )
    expect(theme.reload.cached_settings[:links]).to eq([{ "name" => "猫" }])

    call_tool(
      "discourse_update_theme_setting",
      { theme_id: theme.id, name: "links", operation: "revert", confirm: true },
    )
    expect(response.parsed_body.dig("result", "structuredContent", "value")).to eq(
      [{ "name" => "Home" }],
    )
    expect(theme.reload.cached_settings[:links]).to eq([{ "name" => "Home" }])
  end

  it "creates an unattached theme asset through the upload validation path" do
    authorize
    data = File.binread(file_from_fixtures("fake.woff2", "woff2"))
    call_tool(
      "discourse_upload_theme_asset",
      { filename: "fake.woff2", file_data: Base64.strict_encode64(data) },
    )
    expect(response.status).to eq(200)
    result = response.parsed_body.dig("result", "structuredContent")
    expect(result["attached"]).to eq(false)
    expect(Upload.find(result["upload_id"]).original_filename).to eq("fake.woff2")
  end

  it "rejects filenames containing null bytes before processing uploads" do
    authorize
    call_tool(
      "discourse_upload_theme_asset",
      { filename: "bad\u0000.woff2", file_data: Base64.strict_encode64("data") },
    )
    expect(response.status).to eq(400)
    expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
  end

  it "rejects invalid filename characters across line breaks" do
    authorize
    call_tool(
      "discourse_upload_theme_asset",
      { filename: "bad\u0000\ngood.woff2", file_data: Base64.strict_encode64("data") },
    )
    expect(response.status).to eq(400)
    expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
  end

  it "rejects a second install source even when its URL is blank" do
    authorize
    expect do
      call_tool(
        "discourse_install_theme",
        {
          remote_url: "   ",
          archive_data: archive_data("about.json" => { name: "Archive theme" }.to_json),
          filename: "theme.zip",
          confirm_external_code: true,
        },
      )
    end.not_to change(Theme, :count)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
  end

  it "returns a validation error for an unsupported long file extension" do
    authorize
    call_tool(
      "discourse_upload_theme_asset",
      { filename: "a.#{"x" * 250}", file_data: Base64.strict_encode64("data") },
    )
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
  end

  it "only runs archive migrations when explicitly confirmed" do
    authorize
    data =
      archive_data(
        "about.json" => { name: "Archive theme" }.to_json,
        "settings.yml" => "heading: Welcome\n",
        "migrations/settings/0001-heading.js" =>
          "export default function migrate(settings) { settings.set('heading', 'Migrated'); return settings; }",
      )
    arguments = { archive_data: data, filename: "theme.zip", confirm_external_code: true }
    call_tool("discourse_install_theme", arguments)
    expect(response.status).to eq(200)
    installed = Theme.find(response.parsed_body.dig("result", "structuredContent", "theme", "id"))
    expect(installed.cached_settings[:heading]).to eq("Welcome")

    arguments.merge!(
      replace_theme_id: installed.id,
      expected_name: installed.name,
      confirm_replace: true,
      run_migrations: true,
    )
    call_tool("discourse_install_theme", arguments)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(installed.reload.cached_settings[:heading]).to eq("Welcome")

    call_tool("discourse_install_theme", arguments.merge(confirm_run_migrations: true))
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(installed.reload.cached_settings[:heading]).to eq("Migrated")
  end

  context "with a repository" do
    let(:repo) do
      setup_git_repo(
        "about.json" => { name: "MCP theme" }.to_json,
        "settings.yml" => "heading: Welcome\n",
        "migrations/settings/0001-heading.js" =>
          "export default function migrate(settings) { settings.set('heading', 'Migrated'); return settings; }",
      )
    end
    let(:remote_url) { MockGitImporter.register("https://example.com/mcp-theme.git", repo) }

    around { |example| MockGitImporter.with_mock { example.run } }

    it "requires migrations and confirmation before importing archive components" do
      authorize
      add_to_git_repo(repo, "about.json" => { name: "MCP theme", component: true }.to_json)
      data = archive_data("about.json" => { name: "Parent", components: [remote_url] }.to_json)
      arguments = {
        filename: "theme.zip",
        archive_data: data,
        components: "merge",
        confirm_external_code: true,
      }
      expect {
        call_tool("discourse_install_theme", arguments.merge(run_migrations: false))
      }.not_to change(Theme, :count)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect {
        call_tool("discourse_install_theme", arguments.merge(run_migrations: true))
      }.not_to change(Theme, :count)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      call_tool(
        "discourse_install_theme",
        arguments.merge(run_migrations: true, confirm_run_migrations: true),
      )
      expect(response.parsed_body.dig("result", "isError")).to eq(false)
      expect(Theme.find_by!(name: "MCP theme").cached_settings[:heading]).to eq("Migrated")
    end

    it "reports failed archive components for new themes and replacements" do
      authorize
      add_to_git_repo(repo, "about.json" => "invalid json")
      [false, true].each do |replace|
        data =
          archive_data(
            "about.json" => { name: "Replacement", components: [remote_url] }.to_json,
            "common/header.html" => "Replacement header",
          )
        arguments = {
          filename: "theme.zip",
          archive_data: data,
          confirm_external_code: true,
          components: "merge",
          run_migrations: true,
          confirm_run_migrations: true,
        }
        if replace
          arguments.merge!(
            replace_theme_id: theme.id,
            expected_name: theme.name,
            confirm_replace: true,
          )
        end

        expect { call_tool("discourse_install_theme", arguments) }.to change(Theme, :count).by(
          replace ? 0 : 1,
        )

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("result", "isError")).to eq(false)
        result = response.parsed_body.dig("result", "structuredContent")
        expect(result["skipped_components"]).to contain_exactly(
          "url" => remote_url,
          "error" => I18n.t("themes.import_error.about_json"),
        )
        installed = Theme.find(result["theme"]["id"])
        expect(installed.theme_fields.find_by!(name: "header").value).to eq("Replacement header")
        expect(installed.child_themes).to be_empty
      end
    end

    it "reports skipped components when finishing a remote installation" do
      authorize
      child_repo = setup_git_repo("about.json" => {}.to_json)
      child_url = MockGitImporter.register("https://example.com/bad-child.git", child_repo)
      add_to_git_repo(repo, "about.json" => { name: "Parent", components: [child_url] }.to_json)
      theme.update!(remote_theme: Fabricate(:remote_theme, remote_url:, local_version: nil))
      call_tool(
        "discourse_sync_remote_theme",
        {
          theme_id: theme.id,
          action: "update",
          confirm_external_code: true,
          confirm_run_migrations: true,
        },
      )
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(false)
      result = response.parsed_body.dig("result", "structuredContent")
      expect(result["skipped_components"]).to contain_exactly(
        "url" => child_url,
        "error" => I18n.t("themes.import_error.about_json"),
      )
      expect(result["theme"]).not_to have_key("theme_fields")
      expect(theme.reload.child_themes).to be_empty
      expect(theme.remote_theme).not_to be_placeholder
    end

    it "requires migration confirmation and refuses to silently ignore a request to skip migrations" do
      authorize
      arguments = { remote_url:, confirm_external_code: true }
      expect { call_tool("discourse_install_theme", arguments) }.not_to change { Theme.count }
      expect(response.parsed_body.dig("result", "isError")).to eq(true)

      expect {
        call_tool(
          "discourse_install_theme",
          arguments.merge(confirm_run_migrations: true, run_migrations: false),
        )
      }.not_to change { Theme.count }
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    end

    it "installs a repository, checks its version, and applies a confirmed update" do
      authorize
      call_tool(
        "discourse_install_theme",
        { remote_url:, confirm_external_code: true, confirm_run_migrations: true },
      )
      expect(response.status).to eq(200)
      result = response.parsed_body.dig("result", "structuredContent", "theme")
      installed = Theme.find(result["id"])
      expect(installed.cached_settings[:heading]).to eq("Migrated")

      call_tool("discourse_sync_remote_theme", { theme_id: installed.id, action: "check" })
      expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
      expect(response.parsed_body.dig("result", "structuredContent", "remote_version")).to eq(
        installed.remote_theme.local_version,
      )

      add_to_git_repo(
        repo,
        "migrations/settings/0002-heading.js" =>
          "export default function migrate(settings) { settings.set('heading', 'Updated'); return settings; }",
      )
      call_tool("discourse_sync_remote_theme", { theme_id: installed.id, action: "update" })
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(installed.reload.cached_settings[:heading]).to eq("Migrated")

      call_tool(
        "discourse_sync_remote_theme",
        {
          theme_id: installed.id,
          action: "update",
          confirm_external_code: true,
          confirm_run_migrations: true,
        },
      )
      expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
      expect(installed.reload.cached_settings[:heading]).to eq("Updated")
    end
  end

  context "when a plugin restricts theme editing" do
    fab!(:locked_theme, :theme)
    fab!(:locked_component) { Fabricate(:theme, component: true) }
    let(:plugin) { Plugin::Instance.new }
    let(:modifier) do
      proc do |allowed, _guardian, target|
        allowed && [locked_theme.id, locked_component.id].exclude?(target.id)
      end
    end
    let(:component_url) { "https://example.com/locked-component.git" }
    let(:repo) do
      setup_git_repo("about.json" => { name: "MCP theme", components: [component_url] }.to_json)
    end
    let(:remote_url) { MockGitImporter.register("https://example.com/mcp-theme.git", repo) }

    before do
      authorize
      plugin.register_modifier(:user_guardian_can_edit_theme, &modifier)
      locked_component.update!(remote_theme: RemoteTheme.create!(remote_url: component_url))
    end

    after do
      DiscoursePluginRegistry.unregister_modifier(plugin, :user_guardian_can_edit_theme, &modifier)
    end

    around { |example| MockGitImporter.with_mock { example.run } }

    it "denies writes to a restricted theme even for an admin with the scope" do
      operations
        .except("discourse_list_themes", "discourse_install_theme", "discourse_upload_theme_asset")
        .each do |name, arguments|
          arguments = arguments.merge(theme_id: locked_theme.id)
          arguments[:expected_name] = locked_theme.name if arguments.key?(:expected_name)
          call_tool(name, arguments)
          expect(response.status).to eq(403), "#{name}: #{response.body}"
        end

      archive =
        Base64.strict_encode64(
          File.binread(file_from_fixtures("discourse-test-theme.zip", "themes")),
        )
      call_tool(
        "discourse_install_theme",
        {
          archive_data: archive,
          filename: "theme.zip",
          replace_theme_id: locked_theme.id,
          expected_name: locked_theme.name,
          confirm_replace: true,
          confirm_external_code: true,
        },
      )
      expect(response.status).to eq(403)
      expect(locked_theme.reload.theme_fields).to be_empty
    end

    it "refuses to import a repository that attaches a restricted component" do
      expect do
        call_tool(
          "discourse_install_theme",
          { remote_url:, confirm_external_code: true, confirm_run_migrations: true },
        )
      end.not_to change { Theme.count }
      expect(response.status).to eq(403)
      expect(locked_component.reload.parent_theme_ids).to be_empty
    end

    it "refuses to attach a restricted component while completing a remote placeholder" do
      theme.update!(remote_theme: RemoteTheme.create!(remote_url:))
      call_tool(
        "discourse_sync_remote_theme",
        {
          theme_id: theme.id,
          action: "update",
          confirm_external_code: true,
          confirm_run_migrations: true,
        },
      )
      expect(response.status).to eq(403)
      expect(theme.reload.child_theme_ids).to be_empty
      expect(theme.remote_theme).to be_placeholder
    end

    it "refuses to remove a restricted component through archive replacement" do
      theme.add_relative_theme!(:child, locked_component)
      archive =
        Base64.strict_encode64(
          File.binread(file_from_fixtures("discourse-test-theme.zip", "themes")),
        )
      call_tool(
        "discourse_install_theme",
        {
          archive_data: archive,
          filename: "theme.zip",
          replace_theme_id: theme.id,
          expected_name: theme.name,
          components: "sync",
          run_migrations: true,
          confirm_run_migrations: true,
          confirm_replace: true,
          confirm_external_code: true,
        },
      )
      expect(response.status).to eq(403)
      expect(theme.reload.child_theme_ids).to eq([locked_component.id])
    end
  end

  it "updates declared translations and rolls back a batch containing an unknown key" do
    theme.set_field(target: :translations, name: "en", value: "en:\n  greeting: Hello\n")
    theme.save!
    authorize
    call_tool(
      "discourse_update_theme_translations",
      {
        theme_id: theme.id,
        expected_name: theme.name,
        locale: "en",
        translations: {
          greeting: "猫",
          unknown: "no",
        },
      },
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(theme.reload.translations.find { |entry| entry.key == "greeting" }.value).to eq("Hello")
    call_tool(
      "discourse_update_theme_translations",
      {
        theme_id: theme.id,
        expected_name: theme.name,
        locale: "en",
        translations: {
          greeting: "猫",
        },
      },
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(theme.reload.translations.find { |entry| entry.key == "greeting" }.value).to eq("猫")
  end
end
