# frozen_string_literal: true

require "stringio"

RSpec.describe "customizations export and apply", :rails do
  let(:customizations) { Migrations::Importer::Customizations }
  let(:output) { StringIO.new }
  let(:secret_value) { "0123456789abcdef0123456789abcdef01234567" }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  def create_upload(fixture, filename, **opts)
    UploadCreator.new(file_from_fixtures(fixture), filename, opts).create_for(
      Discourse.system_user.id,
    )
  end

  def font_upload
    path = File.join(@dir, "font.woff2")
    File.binwrite(path, "wOF2 fake font data")
    UploadCreator.new(File.open(path), "font.woff2", for_theme: true).create_for(
      Discourse.system_user.id,
    )
  end

  let!(:logo) { create_upload("logo.png", "logo.png") }
  let!(:flair) { create_upload("smallest.png", "flair.png") }
  let!(:category_logo) { create_upload("logo-dev.png", "category-logo.png") }
  let!(:background) { create_upload("large_icon_correct.png", "background.png") }

  let!(:palette) do
    ColorScheme.create_from_base(
      name: "Custom palette",
      colors: {
        "primary" => "112233",
        "tertiary" => "445566",
      },
    )
  end

  let!(:component) do
    theme = Fabricate(:theme, name: "Custom component", component: true)
    theme.set_field(target: :common, name: :scss, value: ".custom { color: red; }")
    theme.set_field(
      target: :common,
      name: :footer,
      value: "<div class='custom-footer'>Footer</div>",
    )
    theme.set_field(target: :settings, name: :yaml, value: <<~YAML)
      greeting:
        default: "hello"
      background:
        type: upload
        default: ""
    YAML
    theme.set_field(
      target: :common,
      name: "custom_font",
      type: :theme_upload_var,
      upload_id: font_upload.id,
    )
    theme.save!
    theme.update_setting(:greeting, "servus")
    theme.update_setting(:background, background.url)
    theme.save!
    theme
  end

  let!(:parent) do
    theme = Fabricate(:theme, name: "Custom theme", color_scheme: palette)
    theme.add_relative_theme!(:child, component)
    theme
  end

  let!(:flair_group) do
    Fabricate(
      :group,
      name: "flair_group",
      flair_upload: flair,
      flair_bg_color: "ff0000",
      title: "Flair",
    )
  end

  let!(:imported_group) do
    Fabricate(:group, name: "imported_group", title: "Imported").tap do |group|
      GroupCustomField.create!(group_id: group.id, name: "import_id", value: "g-42")
    end
  end

  let!(:category) do
    Fabricate(
      :category,
      name: "Announcements",
      slug: "announcements",
      color: "0088cc",
      uploaded_logo: category_logo,
    ).tap do |category|
      category.set_permissions(flair_group.id => :full, :everyone => :readonly)
      category.save!
    end
  end

  let(:plan) do
    customizations::Plan.new(
      "format_version" => 1,
      "site_settings" => [
        { "name" => "title", "target" => "template" },
        { "name" => "logo", "target" => "template" },
        { "name" => "github_client_secret", "target" => "migrated", "secret" => true },
      ],
      "themes" => [
        { "name" => "Custom component", "target" => "template" },
        { "name" => "Custom theme", "target" => "template" },
      ],
      "color_schemes" => [{ "name" => "Custom palette", "target" => "template" }],
      "groups" => [
        {
          "name" => "flair_group",
          "target" => "template",
          "attributes" => %w[flair_upload flair_bg_color title],
        },
        {
          "name" => "imported_group",
          "match" => {
            "import_id" => "g-42",
          },
          "target" => "migrated",
          "attributes" => ["title"],
        },
      ],
      "categories" => [
        {
          "match" => {
            "slug_path" => "announcements",
          },
          "target" => "template",
          "attributes" => %w[color uploaded_logo permissions],
        },
      ],
      "translation_overrides" => [
        { "locale" => "en", "key" => "js.topic.create", "target" => "template" },
      ],
    )
  end

  let(:bundle_path) { File.join(@dir, "bundle.zip") }

  before do
    SiteSetting.title = "Customized title"
    SiteSetting.logo = logo
    SiteSetting.github_client_secret = secret_value
    TranslationOverride.upsert!("en", "js.topic.create", "Start a discussion")
  end

  def matcher
    customizations::Matcher.build
  end

  def export!
    report = customizations::Exporter.new(plan:, output_path: bundle_path, matcher:, output:).run
    expect(report.entries.map(&:status).uniq).to eq([:exported]), output.string
  end

  def apply!(target, env: {}, dry_run: false)
    secrets = customizations::Secrets.new(env:, input: StringIO.new, output:)
    customizations::Applier.new(bundle_path:, target:, matcher:, dry_run:, secrets:, output:).run
  end

  def statuses(report)
    report.entries.to_h { |entry| ["#{entry.section}: #{entry.label}", entry.status] }
  end

  def wipe!
    [component, parent].each(&:destroy!)
    palette.destroy!
    SiteSetting.title = "Something else"
    SiteSetting.remove_override!(:logo)
    SiteSetting.github_client_secret = ""
    flair_group.update!(flair_upload_id: nil, flair_bg_color: nil, title: nil)
    imported_group.update!(title: nil)
    category.set_permissions(everyone: :full)
    category.update!(color: "000000", uploaded_logo_id: nil)
    TranslationOverride.revert!("en", ["js.topic.create"])
    Upload.where(id: [logo.id, flair.id, category_logo.id, background.id]).delete_all
  end

  def exported_manifest
    customizations::Bundle::Reader.open(bundle_path) { |bundle| bundle.manifest }
  end

  it "never writes secrets unless asked to" do
    export!

    manifest = exported_manifest
    entry = manifest.dig("items", "site_settings").find { |e| e["name"] == "github_client_secret" }
    expect(entry).to include("secret" => true, "value" => nil)
    expect(JSON.generate(manifest)).not_to include(secret_value)

    customizations::Exporter.new(
      plan:,
      output_path: bundle_path,
      matcher:,
      include_secrets: true,
      output:,
    ).run
    expect(JSON.generate(exported_manifest)).to include(secret_value)
    expect(output.string).to include("contains secret values")
  end

  it "stores uploads in the bundle, not ids or URLs" do
    export!

    logo_entry = exported_manifest.dig("items", "site_settings").find { |e| e["name"] == "logo" }
    expect(logo_entry["value"]).to eq(
      "upload" => "uploads/#{logo.sha1}.png",
      "original_filename" => "logo.png",
    )
  end

  it "restores everything on the template and migrated targets, and is idempotent" do
    export!
    wipe!

    dry_run = apply!("template", dry_run: true)
    expect(dry_run.failed?).to eq(false), output.string
    expect(Theme.where(name: "Custom component")).to be_empty

    report = apply!("template")
    expect(report.failed?).to eq(false), output.string

    restored_component = Theme.find_by!(name: "Custom component")
    restored_parent = Theme.find_by!(name: "Custom theme")
    expect(restored_component.component).to eq(true)
    expect(restored_component.theme_fields.find_by(name: "scss").value).to include(".custom")
    font_field = restored_component.theme_fields.find_by(name: "custom_font")
    expect(font_field.upload.original_filename).to eq("font.woff2")
    expect(restored_component.get_setting(:greeting)).to eq("servus")
    expect(restored_component.theme_settings.find_by(name: "background").value.to_i).to eq(
      Upload.find_by(
        sha1: Upload.generate_digest(file_from_fixtures("large_icon_correct.png").path),
      ).id,
    )
    expect(restored_parent.child_themes).to contain_exactly(restored_component)
    expect(restored_parent.color_scheme.name).to eq("Custom palette")
    expect(restored_parent.color_scheme.colors.find_by(name: "primary").hex).to eq("112233")

    expect(SiteSetting.title).to eq("Customized title")
    expect(SiteSetting.logo.original_filename).to eq("logo.png")
    expect(SiteSetting.github_client_secret).to eq("")

    flair_group.reload
    expect(flair_group.flair_upload.original_filename).to eq("flair.png")
    expect(flair_group.flair_bg_color).to eq("ff0000")
    expect(imported_group.reload.title).to be_nil

    category.reload
    expect(category.color).to eq("0088cc")
    expect(category.uploaded_logo.original_filename).to eq("category-logo.png")
    expect(category.read_restricted).to eq(false)
    expect(category.category_groups.pluck(:group_id, :permission_type)).to contain_exactly(
      [flair_group.id, CategoryGroup.permission_types[:full]],
      [Group::AUTO_GROUPS[:everyone], CategoryGroup.permission_types[:readonly]],
    )
    expect(
      TranslationOverride.find_by(locale: "en", translation_key: "js.topic.create").value,
    ).to eq("Start a discussion")

    migrated_report =
      apply!("migrated", env: { "DISCO_SECRET_GITHUB_CLIENT_SECRET" => secret_value })
    expect(migrated_report.failed?).to eq(false), output.string
    expect(SiteSetting.github_client_secret).to eq(secret_value)
    expect(imported_group.reload.title).to eq("Imported")
    expect(statuses(migrated_report)["groups: imported_group"]).to eq(:changed)
    expect(migrated_report.entries.find { |e| e.label == "imported_group" }.message).to eq(
      "matched by import_id",
    )

    again = apply!("template")
    expect(again.entries.map(&:status).uniq).to eq([:unchanged]), output.string

    again_migrated =
      apply!("migrated", env: { "DISCO_SECRET_GITHUB_CLIENT_SECRET" => secret_value })
    expect(again_migrated.entries.map(&:status).uniq).to eq([:unchanged]), output.string
  end

  it "fails a category whose permission group is missing on the destination" do
    other_group = Fabricate(:group, name: "other_group")
    category.set_permissions(other_group.id => :full)
    category.save!
    export!
    category.set_permissions(everyone: :full)
    category.save!
    other_group.destroy!

    report = apply!("template")

    entry = report.entries.find { |e| e.section == "categories" }
    expect(entry.status).to eq(:failed)
    expect(entry.message).to include("group 'other_group' does not exist")
  end

  it "treats NULL and empty strings as equal when comparing attributes" do
    group = Fabricate(:group, bio_raw: nil, flair_icon: nil)
    differences =
      customizations::Apply::Attributes.differences(group, { "bio_raw" => "", "flair_icon" => "" })

    expect(differences).to be_empty
  end

  it "skips imported records it can't find and secrets it isn't given" do
    export!
    imported_group.destroy!

    report = apply!("migrated")

    expect(statuses(report)).to include(
      "groups: imported_group" => :skipped,
      "site_settings: github_client_secret" => :skipped,
    )
    expect(report.failed?).to eq(false)
  end

  it "skips settings the destination overrides with a global setting" do
    export!
    SiteSetting.title = "Something else"
    allow(SiteSetting).to receive(:shadowed_settings).and_return(Set[:title])

    report = apply!("template")

    expect(statuses(report)).to include("site_settings: title" => :skipped)
    expect(SiteSetting.title).to eq("Something else")
  end
end
