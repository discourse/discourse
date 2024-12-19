# frozen_string_literal: true

module Discourse
  VERSION_REGEXP ||= /\A\d+\.\d+\.\d+(\.beta\d+)?\z/
  VERSION_COMPATIBILITY_FILENAME ||= ".discourse-compatibility"
  # work around reloader
  unless defined?(::Discourse::VERSION)
    module VERSION #:nodoc:
      # Use the `version_bump:*` rake tasks to update this value
      STRING = "3.3.3"

      PARTS = STRING.split(".")
      private_constant :PARTS

      MAJOR = PARTS[0].to_i
      MINOR = PARTS[1].to_i
      TINY = PARTS[2].to_i
      PRE = PARTS[3]&.split("-", 2)&.[](0)
      DEV = PARTS[3]&.split("-", 2)&.[](1)
    end
  end

  class InvalidVersionListError < StandardError
  end

  def self.has_needed_version?(current, needed)
    Gem::Version.new(current) >= Gem::Version.new(needed)
  end

  # lookup an external resource (theme/plugin)'s best compatible version
  # compatible resource files are YAML, in the format:
  # `discourse_version: plugin/theme git reference.` For example:
  #  2.5.0.beta6: c4a6c17
  #  2.5.0.beta4: d1d2d3f
  #  2.5.0.beta2: bbffee
  #  2.4.4.beta6: some-other-branch-ref
  #  2.4.2.beta1: v1-tag
  def self.find_compatible_resource(version_list, target_version = ::Discourse::VERSION::STRING)
    return if version_list.blank?

    begin
      version_list = YAML.safe_load(version_list)
    rescue Psych::SyntaxError, Psych::DisallowedClass => e
    end

    raise InvalidVersionListError unless version_list.is_a?(Hash)

    version_list =
      version_list
        .transform_keys do |v|
          Gem::Requirement.parse(v)
        rescue Gem::Requirement::BadRequirementError => e
          raise InvalidVersionListError, "Invalid version specifier: #{v}"
        end
        .sort_by do |parsed_requirement, _|
          operator, version = parsed_requirement
          [version, operator == "<" ? 0 : 1]
        end

    parsed_target_version = Gem::Version.new(target_version)

    lowest_matching_entry =
      version_list.find do |parsed_requirement, target|
        req_operator, req_version = parsed_requirement
        req_operator = "<=" if req_operator == "="

        if !%w[<= <].include?(req_operator)
          raise InvalidVersionListError,
                "Invalid version specifier operator for '#{req_operator} #{req_version}'. Operator must be one of <= or <"
        end

        resolved_requirement = Gem::Requirement.new("#{req_operator} #{req_version}")
        resolved_requirement.satisfied_by?(parsed_target_version)
      end

    return if lowest_matching_entry.nil?

    checkout_version = lowest_matching_entry[1]

    begin
      Discourse::Utils.execute_command "git",
                                       "check-ref-format",
                                       "--allow-onelevel",
                                       checkout_version
    rescue RuntimeError
      raise InvalidVersionListError, "Invalid ref name: #{checkout_version}"
    end

    checkout_version
  end

  # Find a compatible resource from a git repo
  def self.find_compatible_git_resource(path)
    return unless File.directory?("#{path}/.git")

    tree_info =
      Discourse::Utils.execute_command(
        "git",
        "-C",
        path,
        "ls-tree",
        "-l",
        "HEAD",
        Discourse::VERSION_COMPATIBILITY_FILENAME,
      )
    blob_size = tree_info.split[3].to_i

    if blob_size > Discourse::MAX_METADATA_FILE_SIZE
      $stderr.puts "#{Discourse::VERSION_COMPATIBILITY_FILENAME} file in #{path} too big"
      return
    end

    compat_resource =
      Discourse::Utils.execute_command(
        "git",
        "-C",
        path,
        "show",
        "HEAD@{upstream}:#{Discourse::VERSION_COMPATIBILITY_FILENAME}",
      )

    Discourse.find_compatible_resource(compat_resource)
  rescue InvalidVersionListError => e
    $stderr.puts "Invalid version list in #{path}"
  rescue Discourse::Utils::CommandError => e
    nil
  end
end
