# frozen_string_literal: true

module ReleaseUtils
  class Version
    include Comparable

    PRE_RELEASE = "latest"

    attr_reader :major, :minor, :patch, :pre, :revision

    protected attr_reader :gem_version

    def initialize(version_string)
      @gem_version = Gem::Version.new(version_string)

      segments = gem_version.segments
      @major = segments[0]
      @minor = segments[1] || 1
      @patch = segments[2] || 0

      @pre, @revision = segments.drop(3).drop_while { it == "pre" } if gem_version.prerelease?

      freeze
    end

    class << self
      def current
        version_string = File.read("lib/version.rb")[/STRING = "(.*)"/, 1]
        raise "Unable to parse current version from lib/version.rb" unless version_string
        new(version_string)
      end

      def next
        target = new("#{Time.current.strftime("%Y.%-m")}.0-#{PRE_RELEASE}")
        return target if target > current
        current.next_development_cycle
      end
    end

    def <=>(other)
      other = self.class.new(other) if other.is_a?(String)
      return unless other.is_a?(self.class)
      gem_version <=> other.gem_version
    end

    def same_development_cycle?(other)
      development? && other.development? && without_revision == other.without_revision
    end

    def same_series?(other)
      series == other.series
    end

    def development?
      pre == PRE_RELEASE
    end

    def series
      "#{major}.#{minor}"
    end

    def branch_name
      "release/#{series}"
    end

    def tag_name
      "v#{self}"
    end

    def without_revision
      return self unless revision
      self.class.new("#{major}.#{minor}.#{patch}-#{pre}")
    end

    def next_development_cycle
      carry, new_minor = minor.divmod(12)
      self.class.new("#{major + carry}.#{new_minor + 1}.0-#{PRE_RELEASE}")
    end

    def next_revision
      raise "next_revision can only be called on development versions" unless development?
      self.class.new("#{major}.#{minor}.#{patch}-#{pre}.#{revision.to_i + 1}")
    end

    def to_s
      "#{major}.#{minor}.#{patch}#{"-#{pre}" if pre}#{".#{revision}" if revision}"
    end

    def inspect
      "#<#{self.class} #{self}>"
    end
  end
end
