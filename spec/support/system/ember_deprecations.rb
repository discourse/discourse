# frozen_string_literal: true

# JS deprecation enforcement for system specs: opt core/preinstalled
# plugins/themes into raising on Ember deprecations, surface fatal deprecations,
# and count non-fatal ones.
module EmberDeprecations
  # Raise on Ember deprecations only for code we own (core specs, preinstalled
  # plugins, preinstalled themes), unless the caller already set the flag.
  def self.set_raise_on_deprecation!(example)
    return unless ENV["EMBER_RAISE_ON_DEPRECATION"].nil?

    example_file_path = example.metadata[:rerun_file_path]
    return if example_file_path.nil?

    match =
      example_file_path.to_s.match(
        %r{^#{Regexp.escape(Rails.root.to_s)}/(plugins|themes|spec)/([^/]+)/},
      )
    return if match.nil?

    type_dir, extension_name = match.captures

    should_set =
      case type_dir
      when "spec"
        true
      when "plugins"
        Discourse.preinstalled_plugins.any? { |p| p.directory_name == extension_name }
      when "themes"
        # Preinstalled themes don't have a .git directory
        !Rails.root.join(type_dir, extension_name, ".git").exist?
      end

    ENV["EMBER_RAISE_ON_DEPRECATION"] = "1" if should_set
  end

  # Formatted error for the first fatal JS deprecation in the logs, or nil.
  def self.fatal_error(logs)
    logs
      &.filter_map do |log|
        if log[:level] == "trace"
          error = JSON.parse(log[:message][/^fatal_deprecation:(.+)$/, 1])
          "~~~~~~~ JS ERROR ~~~~~~~\n#{error}\n~~~~~ END JS ERROR ~~~~~"
        end
      end
      &.first
  end

  # Count non-fatal deprecation_id counts into the example metadata, excluding
  # any the spec opted into via `expected_js_deprecations`.
  def self.record_counts(logs, metadata)
    expected = metadata[:expected_js_deprecations] || []

    logs&.each do |log|
      next if log[:level] != "count"
      deprecation_id = log[:message][/^deprecation_id:(.+?):\s*\d+$/, 1]
      next if deprecation_id.nil?
      next if expected.include?(deprecation_id)

      deprecations = metadata[:js_deprecations] ||= Hash.new(0)
      deprecations[deprecation_id] += 1
    end
  end
end
