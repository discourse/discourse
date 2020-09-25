# frozen_string_literal: true

module PublicJsVersions

  def self.known_versions(versioned_name)
    versions = Dir["#{File.join(Rails.root, 'public', 'javascripts', versioned_name)}/*"].collect { |p| p.split('/').last }
    versions.sort { |a, b| Gem::Version.new(a) <=> Gem::Version.new(b) }
  end

  def self.versioned_path(versioned_name)
    versions = YAML.load(File.read(File.join(Rails.root, 'config', 'public_js_versions.yml')))
    versions[versioned_name]
  end

end
