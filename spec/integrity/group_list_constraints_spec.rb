# frozen_string_literal: true

# Walks the settings definitions on disk so a mistyped group rule is caught here
# rather than degrading silently on a production boot. The yaml is read directly,
# without booting the settings pipeline, so plugin definitions are checked even in
# the core test run, where plugins are not loaded.
RSpec.describe "group list constraints integrity" do
  # Core and the styleguide plugin are held to the strict tier: they must use the
  # declarative syntax and may only reference automatic groups, whose ids are the
  # same on every site. The remaining bundled plugins are checked for schema
  # validity only, because migrating them is a follow-up.
  def core_yaml
    Rails.root.join("config/site_settings.yml")
  end

  def strict_paths
    [core_yaml, Rails.root.join("plugins/styleguide/config/settings.yml")]
  end

  def all_paths
    [core_yaml] +
      Dir[Rails.root.join("plugins/*/config/settings.yml")].sort.map { Pathname.new(_1) }
  end

  # Yields [setting_name, default, opts] for every group list defined in `path`.
  def each_group_list(path)
    return to_enum(:each_group_list, path) unless block_given?

    SiteSettings::YamlLoader
      .new(path.to_s)
      .load do |_category, name, default, opts|
        next unless opts.is_a?(Hash) && opts[:type].to_s == "group_list"
        yield name.to_sym, default, opts
      end
  end

  def compile(name, opts)
    SiteSettings::GroupListConstraints.from_opts!(opts, name:, group_type: true)
  end

  def label(path, name)
    "#{path.relative_path_from(Rails.root)} #{name}"
  end

  it "finds the group lists it is meant to be guarding" do
    expect(each_group_list(core_yaml).count).to be > 30
  end

  it "compiles every group list without a schema error" do
    failures =
      all_paths.flat_map do |path|
        each_group_list(path).filter_map do |name, _default, opts|
          _constraints, errors = compile(name, opts)
          "#{label(path, name)}: #{errors.join(" ")}" if errors.present?
        end
      end

    expect(failures).to eq([])
  end

  it "resolves every declared default to group ids" do
    failures =
      all_paths.flat_map do |path|
        each_group_list(path).filter_map do |name, default, _opts|
          SiteSettings::GroupRefs.resolve_list(default, context: name.to_s)
          nil
        rescue SiteSettings::GroupRefs::SchemaError => error
          "#{label(path, name)}: #{error.message}"
        end
      end

    expect(failures).to eq([])
  end

  it "keeps core and the styleguide free of the legacy group keys" do
    failures =
      strict_paths.flat_map do |path|
        each_group_list(path).filter_map do |name, _default, opts|
          declared = %i[mandatory_values disallowed_groups].select { |key| opts.key?(key) }
          declared << :validator if opts[:validator] == "AtLeastOneGroupValidator"
          "#{label(path, name)}: #{declared.join(", ")}" if declared.any?
        end
      end

    expect(failures).to eq([])
  end

  it "keeps core and styleguide rules on automatic groups only" do
    failures =
      strict_paths.flat_map do |path|
        each_group_list(path).filter_map do |name, default, opts|
          rules = compile(name, opts).first
          ids =
            SiteSettings::GroupRefs.resolve_ids(default, context: name.to_s) + rules.mandatory_ids +
              rules.disallowed_ids
          stray = ids.uniq - Group::AUTO_GROUPS.values
          "#{label(path, name)}: #{stray.join(", ")}" if stray.any?
        end
      end

    expect(failures).to eq([])
  end

  it "keeps every core and styleguide default consistent with its own rules" do
    failures =
      strict_paths.flat_map do |path|
        each_group_list(path).filter_map do |name, default, opts|
          constraints, = compile(name, opts)
          resolved = SiteSettings::GroupRefs.resolve_list(default, context: name.to_s)
          constraints.validate_default!(resolved, name:)
          nil
        rescue SiteSettings::GroupListConstraints::SchemaError => error
          "#{path.relative_path_from(Rails.root)}: #{error.message}"
        end
      end

    expect(failures).to eq([])
  end
end
