# frozen_string_literal: true

module Discourse
  VERSION_REGEXP ||= /\A\d+\.\d+\.\d+(\.beta\d+)?\z/
  VERSION_COMPATIBILITY_FILENAME ||= ".discourse-compatibility"

  # work around reloader
  unless defined? ::Discourse::VERSION
    module VERSION #:nodoc:
      MAJOR = 2
      MINOR = 9
      TINY  = 0
      PRE   = 'beta1'

      STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
    end
  end

  class InvalidVersionListError < StandardError; end

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
  def self.find_compatible_resource(version_list, version = ::Discourse::VERSION::STRING)
    return unless version_list

    begin
      version_list = YAML.safe_load(version_list)
    rescue Psych::SyntaxError, Psych::DisallowedClass => e
    end

    raise InvalidVersionListError unless version_list.is_a?(Hash)

    version_list = version_list.sort_by { |v, pin| Gem::Version.new(v) }.reverse

    # If plugin compat version is listed as less than current Discourse version, take the version/hash listed before.
    checkout_version = nil
    version_list.each do |core_compat, target|
      if Gem::Version.new(core_compat) == Gem::Version.new(version) # Exact version match - return it
        checkout_version = target
        break
      elsif Gem::Version.new(core_compat) < Gem::Version.new(version) # Core is on a higher version than listed, use a later version
        break
      end
      checkout_version = target
    end

    return if checkout_version.nil?

    begin
      Discourse::Utils.execute_command "git", "check-ref-format", "--allow-onelevel", checkout_version
    rescue RuntimeError
      raise InvalidVersionListError, "Invalid ref name: #{checkout_version}"
    end

    checkout_version
  end

  # Find a compatible resource from a git repo
  def self.find_compatible_git_resource(path)
    return unless File.directory?("#{path}/.git")
    compat_resource, std_error, s = Open3.capture3("git -C '#{path}' show HEAD@{upstream}:#{Discourse::VERSION_COMPATIBILITY_FILENAME}")
    Discourse.find_compatible_resource(compat_resource) if s.success?
  rescue InvalidVersionListError => e
    $stderr.puts "Invalid version list in #{path}"
  end
end
