# frozen_string_literal: true

require "tmpdir"

load Rails.root.join("script/upcoming_changes_lint.rb")

RSpec.describe UpcomingChangesFileValidator do
  let(:root) { Dir.mktmpdir("upcoming-changes-lint") }
  let(:core_file) { File.join(root, "config/site_settings.yml") }
  let(:plugin_dir) { File.join(root, "plugins/my-plugin") }
  let(:plugin_file) { File.join(plugin_dir, "config/settings.yml") }

  before do
    write_yaml(core_file, core_settings)
    FileUtils.mkdir_p(plugin_dir)
    File.write(File.join(plugin_dir, "plugin.rb"), "enabled_site_setting :my_plugin_enabled\n")
  end

  after { FileUtils.remove_entry(root) }

  let(:core_settings) do
    {
      "core_groups" => {
        "default" => "",
        "type" => "group_list",
      },
      "core_text" => {
        "default" => "",
      },
    }
  end

  def write_yaml(path, settings)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, { "category" => settings }.to_yaml)
  end

  def change(**metadata)
    {
      "default" => false,
      "client" => true,
      "hidden" => true,
      "upcoming_change" => {
        "status" => "alpha",
        "impact" => "feature,all_members",
        "learn_more_url" => "https://meta.discourse.org/t/-/123",
      }.merge(metadata.stringify_keys).compact,
    }
  end

  def errors_for(file)
    validator = described_class.new(file, core_settings_file: core_file)
    validator.has_errors?
    validator.errors
  end

  def core_errors(setting)
    write_yaml(core_file, core_settings.merge("my_change" => setting))
    errors_for(core_file)
  end

  def plugin_errors(setting, name: "my_change")
    write_yaml(
      plugin_file,
      {
        "my_plugin_enabled" => {
          "default" => false,
        },
        "plugin_groups" => {
          "default" => "",
          "type" => "group_list",
        },
        "plugin_text" => {
          "default" => "",
        },
        name => setting,
      },
    )
    errors_for(plugin_file)
  end

  it "accepts valid changes in core and plugins" do
    expect(core_errors(change)).to be_empty
    expect(plugin_errors(change)).to be_empty
  end

  it "ignores settings that are not upcoming changes" do
    expect(core_errors({ "default" => true })).to be_empty
  end

  it "requires `hidden`, `client` and `default: false`" do
    setting = change.merge("hidden" => false, "client" => false, "default" => true)

    expect(core_errors(setting)).to eq(
      [
        "my_change must set `hidden: true`",
        "my_change must set `client: true`",
        "my_change must set `default: false`",
      ],
    )
  end

  it "rejects unsupported keys" do
    expect(core_errors(change(colour: "red"))).to contain_exactly(
      a_string_starting_with("my_change has unsupported upcoming_change keys: colour."),
    )
  end

  it "requires `status` and `impact`" do
    expect(core_errors(change(impact: nil))).to eq(
      [
        "my_change is missing required upcoming_change keys: impact",
        "my_change must set upcoming_change.impact as `type,role`, got nil",
      ],
    )
  end

  it "rejects unknown statuses" do
    expect(core_errors(change(status: "gamma"))).to contain_exactly(
      a_string_starting_with("my_change has invalid upcoming_change status :gamma."),
    )
  end

  it "rejects an empty status" do
    setting = change
    setting["upcoming_change"]["status"] = nil

    expect(core_errors(setting)).to contain_exactly(
      a_string_starting_with("my_change has invalid upcoming_change status nil."),
    )
  end

  it "validates the impact type and role" do
    expect(core_errors(change(impact: "feature"))).to eq(
      ["my_change must set upcoming_change.impact as `type,role`, got \"feature\""],
    )
    expect(core_errors(change(impact: "bugfix,staff"))).to contain_exactly(
      a_string_starting_with("my_change has invalid upcoming_change impact type \"bugfix\"."),
    )
    expect(core_errors(change(impact: "other,everyone"))).to contain_exactly(
      a_string_starting_with("my_change has invalid upcoming_change impact role \"everyone\"."),
    )
  end

  it "requires a short meta `learn_more_url` unless the change is conceptual" do
    expect(core_errors(change(learn_more_url: nil))).to eq(
      ["my_change must set `upcoming_change.learn_more_url` when status is not `conceptual`"],
    )
    expect(
      core_errors(change(learn_more_url: "https://meta.discourse.org/t/some-slug/123")),
    ).to contain_exactly(a_string_including("must match https://meta.discourse.org/t/-/NNNN"))
    expect(core_errors(change(status: "conceptual", learn_more_url: nil))).to be_empty
  end

  describe "group_setting" do
    it "accepts a core or own-plugin group_list setting" do
      expect(core_errors(change(group_setting: "core_groups"))).to be_empty
      expect(plugin_errors(change(group_setting: "core_groups"))).to be_empty
      expect(plugin_errors(change(group_setting: "plugin_groups"))).to be_empty
    end

    it "rejects settings that are not group lists" do
      expect(core_errors(change(group_setting: "core_text"))).to eq(
        ["my_change `upcoming_change.group_setting` must reference a group-list setting"],
      )
    end

    it "rejects settings outside core and the change's own plugin" do
      write_yaml(
        File.join(root, "plugins/other-plugin/config/settings.yml"),
        { "other_groups" => { "default" => "", "type" => "group_list" } },
      )

      expect(plugin_errors(change(group_setting: "other_groups"))).to eq(
        [
          "my_change must reference a core setting or a setting from its own plugin",
          "my_change `upcoming_change.group_setting` must reference a group-list setting",
        ],
      )
    end

    it "rejects an empty value" do
      expect(core_errors(change(group_setting: ""))).to include(
        "my_change `upcoming_change.group_setting` must name a group-list setting",
      )
    end

    it "can't be combined with `allow_enabled_for`" do
      setting = change(group_setting: "core_groups", allow_enabled_for: ["staff"])

      expect(core_errors(setting)).to eq(
        ["my_change may not combine `group_setting` and `allow_enabled_for`"],
      )
    end
  end

  describe "allow_enabled_for" do
    it "accepts known values" do
      expect(core_errors(change(allow_enabled_for: %w[staff specific_groups]))).to be_empty
      expect(core_errors(change(allow_enabled_for: ["everyone"]))).to be_empty
      expect(core_errors(change(allow_enabled_for: ["logged_in_users"]))).to be_empty
    end

    it "must be an array" do
      expect(core_errors(change(allow_enabled_for: "staff"))).to eq(
        ["my_change `upcoming_change.allow_enabled_for` must be an array"],
      )
    end

    it "rejects unknown values" do
      expect(core_errors(change(allow_enabled_for: %w[staff admins]))).to contain_exactly(
        a_string_starting_with(
          "my_change `upcoming_change.allow_enabled_for` contains invalid values: admins.",
        ),
      )
    end

    it "can't combine `everyone` with other values" do
      expect(core_errors(change(allow_enabled_for: %w[everyone staff]))).to eq(
        [
          "my_change `upcoming_change.allow_enabled_for` may not combine `everyone` with other values",
        ],
      )
    end

    it "can't combine `logged_in_users` with other values" do
      expect(core_errors(change(allow_enabled_for: %w[logged_in_users specific_groups]))).to eq(
        [
          "my_change `upcoming_change.allow_enabled_for` may not combine `logged_in_users` with other values",
        ],
      )
    end
  end

  it "requires boolean flags" do
    setting = change(body_class: "yes", permanent_warning: 1, requires_plugin_enabled: "no")

    expect(plugin_errors(setting)).to eq(
      [
        "my_change `upcoming_change.body_class` must be a boolean",
        "my_change `upcoming_change.permanent_warning` must be a boolean",
        "my_change `upcoming_change.requires_plugin_enabled` must be a boolean",
      ],
    )
  end

  describe "requires_plugin_enabled" do
    it "is only allowed on plugin changes" do
      expect(plugin_errors(change(requires_plugin_enabled: false))).to be_empty
      expect(core_errors(change(requires_plugin_enabled: false))).to eq(
        ["my_change sets `upcoming_change.requires_plugin_enabled` but is not owned by a plugin"],
      )
    end

    it "must be false on the plugin's own `enabled_site_setting`" do
      expect(plugin_errors(change, name: "my_plugin_enabled")).to eq(
        [
          "my_plugin_enabled is its plugin's own `enabled_site_setting` and must set `upcoming_change.requires_plugin_enabled: false`, otherwise the change gates itself",
        ],
      )
      expect(
        plugin_errors(change(requires_plugin_enabled: false), name: "my_plugin_enabled"),
      ).to be_empty
    end
  end

  describe "hide_settings" do
    it "accepts core and own-plugin settings" do
      expect(plugin_errors(change(hide_settings: %w[core_text plugin_text]))).to be_empty
    end

    it "must be an array" do
      expect(core_errors(change(hide_settings: "core_text"))).to eq(
        ["my_change `upcoming_change.hide_settings` must be an array"],
      )
    end

    it "rejects unknown settings" do
      expect(core_errors(change(hide_settings: %w[core_text plugin_text]))).to eq(
        ["my_change `upcoming_change.hide_settings` references unknown site settings: plugin_text"],
      )
    end
  end

  it "reports files it can't load" do
    write_yaml(core_file, { "broken" => { "client" => true } })

    expect(errors_for(core_file)).to contain_exactly(
      a_string_including("Failed to parse #{core_file}"),
    )
  end
end

RSpec.describe UpcomingChangesLinter do
  it "prints errors grouped by file and exits with an error" do
    Dir.mktmpdir("upcoming-changes-lint") do |dir|
      path = File.join(dir, "settings.yml")
      File.write(
        path,
        {
          "category" => {
            "my_change" => {
              "default" => false,
              "upcoming_change" => {
                "status" => "alpha",
              },
            },
          },
        }.to_yaml,
      )

      expect { described_class.new([path]).run }.to output(
        /Errors in #{Regexp.escape(path)}.*\n  \* my_change must set `hidden: true`/,
      ).to_stdout.and raise_error(an_object_having_attributes(class: SystemExit, status: 1))
    end
  end
end
