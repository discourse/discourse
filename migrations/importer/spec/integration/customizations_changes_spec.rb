# frozen_string_literal: true

require "stringio"

RSpec.describe "customizations changed since a snapshot", :rails do
  let(:customizations) { Migrations::Importer::Customizations }
  let(:output) { StringIO.new }
  let(:matcher) { customizations::Matcher.build }
  let(:bundle_path) { File.join(@dir, "bundle.zip") }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  def export_diff(tables)
    facts = customizations::Plan::SiteFacts.new(matcher)
    plan, = customizations::Plan::Builder.new({ "tables" => tables }, facts).build
    export_items(plan)
  end

  def export_items(items)
    plan = customizations::Plan.new({ "format_version" => 1 }.merge(items))
    report = customizations::Exporter.new(plan:, output_path: bundle_path, matcher:, output:).run
    expect(report.failed?).to eq(false), output.string
  end

  def apply!(dry_run: false)
    report =
      customizations::Applier.new(bundle_path:, target: "template", matcher:, dry_run:, output:).run
    expect(report.failed?).to eq(false), output.string
    report
  end

  it "transfers administrator-only permissions and restores public access" do
    category = Fabricate(:category)
    [true, false].each do |restricted|
      category.set_permissions(restricted ? {} : { everyone: :full })
      category.save!
      expect(category.category_groups).to be_empty
      export_diff(
        "categories" => {
          "changed" => [
            {
              "after" => category.attributes,
              "diffs" => {
                "read_restricted" => [!restricted, restricted],
              },
            },
          ],
        },
      )
      category.set_permissions(restricted ? { everyone: :full } : {})
      category.save!

      apply!(dry_run: true)
      expect(category.reload.read_restricted).to eq(!restricted)
      apply!
      expect(category.reload.read_restricted).to eq(restricted)
      expect(apply!.entries.map(&:status)).to eq([:unchanged])
    end
  end

  it "creates a group with default attributes before applying category permissions" do
    group = Group.create!(name: "new_access_group")
    category = Fabricate(:category)
    category.set_permissions(group.id => :full)
    category.save!
    export_diff(
      "groups" => {
        "added" => [group.attributes],
      },
      "category_groups" => {
        "added" => category.category_groups.map(&:attributes),
      },
    )
    category.set_permissions(everyone: :full)
    category.save!
    group.destroy!

    apply!(dry_run: true)
    expect(Group.exists?(name: group.name)).to eq(false)
    apply!
    restored = Group.find_by!(name: group.name)
    expect(category.reload.category_groups.pluck(:group_id, :permission_type)).to eq(
      [[restored.id, CategoryGroup.permission_types[:full]]],
    )
    expect(apply!.entries.map(&:status)).to eq(%i[unchanged unchanged])
  end

  it "removes deleted local theme fields and reset translation overrides" do
    theme = Fabricate(:theme)
    theme.set_field(target: :common, name: :header, value: "Old header")
    theme.set_field(target: :translations, name: :en, value: "en:\n  greeting: Hello\n")
    theme.save!
    field = theme.theme_fields.find_by!(name: "header")
    override =
      theme.theme_translation_overrides.create!(
        locale: "en",
        translation_key: "greeting",
        value: "Old greeting",
      )
    theme.theme_translation_overrides.create!(
      locale: "de",
      translation_key: "greeting",
      value: "Hallo",
    )
    removed_field = field.attributes
    removed_override = override.attributes
    field.destroy!
    override.destroy!
    export_diff(
      "theme_fields" => {
        "removed" => [removed_field],
      },
      "theme_translation_overrides" => {
        "removed" => [removed_override],
      },
    )
    theme.set_field(target: :common, name: :header, value: "Old header")
    theme.save!
    theme.theme_translation_overrides.create!(
      removed_override.except("id", "created_at", "updated_at"),
    )

    apply!(dry_run: true)
    expect(theme.theme_fields.exists?(name: "header")).to eq(true)
    expect(theme.theme_translation_overrides.exists?(locale: "en")).to eq(true)
    apply!
    theme.reload
    expect(theme.theme_fields.exists?(name: "header")).to eq(false)
    expect(theme.theme_translation_overrides.pluck(:locale, :translation_key, :value)).to eq(
      [%w[de greeting Hallo]],
    )
    expect(apply!.entries.map(&:status)).to eq(%i[unchanged unchanged])
  end

  it "clears destination translation overrides when the exported snapshot is empty" do
    theme = Fabricate(:theme)
    export_items("themes" => [{ "name" => theme.name, "target" => "template" }])
    override =
      theme.theme_translation_overrides.create!(
        locale: "en",
        translation_key: "greeting",
        value: "Old greeting",
      )

    apply!(dry_run: true)
    expect(ThemeTranslationOverride.exists?(override.id)).to eq(true)
    apply!
    expect(theme.reload.theme_translation_overrides).to be_empty
    expect(apply!.entries.map(&:status)).to eq(%i[unchanged unchanged])
  end

  describe "git themes" do
    let(:repo) do
      @repo =
        setup_git_repo(
          "about.json" =>
            JSON.generate(
              name: "Repository theme",
              color_schemes: {
                "Repository palette" => {
                  primary: "112233",
                },
              },
            ),
          "common/header.html" => "Main branch",
        )
    end
    let(:url) { MockGitImporter.register("https://example.com/customizations.git", repo) }

    around do |example|
      importer =
        Class.new(MockGitImporter) do
          def import!
            super
            execute("git", "checkout", @branch) if @branch.present?
          end
        end
      stub_const(ThemeStore, :GitImporter, importer) { example.run }
    ensure
      FileUtils.rm_rf(@repo) if @repo
    end

    it "preserves renamed themes and their default theme reference" do
      theme = RemoteTheme.import_theme(url)
      theme.update!(name: "Site theme")
      SiteSetting.default_theme_id = theme.id
      export_items(
        "themes" => [{ "name" => theme.name, "target" => "template" }],
        "site_settings" => [{ "name" => "default_theme_id", "target" => "template" }],
      )
      theme.destroy!

      apply!
      restored = Theme.find_by!(name: "Site theme")
      expect(restored.remote_theme.remote_url).to eq(url)
      expect(SiteSetting.default_theme_id).to eq(restored.id)
      restored.update!(name: "Destination name")
      apply!
      expect(restored.reload.name).to eq("Site theme")
      expect(apply!.entries.map(&:status)).to eq(%i[unchanged unchanged unchanged])
    end

    it "switches an existing installation to the exported branch before applying settings" do
      system("git", "-C", repo, "checkout", "-qb", "custom", exception: true)
      File.write(File.join(repo, "settings.yaml"), "greeting: hello\n")
      File.write(File.join(repo, "common/header.html"), "Custom branch")
      system("git", "-C", repo, "add", ".", exception: true)
      system("git", "-C", repo, "commit", "-qm", "Customize theme", exception: true)
      system("git", "-C", repo, "checkout", "-q", "main", exception: true)
      theme = RemoteTheme.import_theme(url, branch: "custom")
      theme.update_setting(:greeting, "Welcome")
      theme.save!
      export_items("themes" => [{ "name" => theme.name, "target" => "template" }])
      theme.destroy!
      destination = RemoteTheme.import_theme(url, branch: "main")

      apply!(dry_run: true)
      expect(destination.remote_theme.reload.branch).to eq("main")
      apply!
      expect(destination.remote_theme.reload.branch).to eq("custom")
      expect(destination.theme_fields.find_by!(name: "header").value).to eq("Custom branch")
      expect(destination.theme_settings.find_by!(name: "greeting").value).to eq("Welcome")
      expect(Theme.joins(:remote_theme).where(remote_themes: { remote_url: url }).count).to eq(1)
      expect(apply!.entries.map(&:status)).to eq(%i[unchanged unchanged])
    end

    it "restores database palette edits after installing their git theme" do
      theme = RemoteTheme.import_theme(url)
      palette = theme.color_schemes.find_by!(name: "Repository palette")
      color = palette.color_scheme_colors.find_by!(name: "primary")
      color.update!(hex: "abcdef")
      export_diff(
        "color_scheme_colors" => {
          "changed" => [{ "after" => color.attributes, "diffs" => { "hex" => %w[112233 abcdef] } }],
        },
      )
      theme.destroy!

      apply!
      restored = Theme.find_by!(name: theme.name).color_schemes.find_by!(name: palette.name)
      expect(restored.color_scheme_colors.find_by!(name: "primary").hex).to eq("abcdef")
      expect(apply!.entries.map(&:status)).to eq(%i[unchanged unchanged unchanged])
    end
  end
end
