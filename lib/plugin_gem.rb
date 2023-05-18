# frozen_string_literal: true

module PluginGem
  def self.load(path, name, version, opts = nil)
    opts ||= {}

    gems_path = File.dirname(path) + "/gems/#{RUBY_VERSION}"

    spec_path = gems_path + "/specifications"

    spec_file = spec_path + "/#{name}-#{version}"

    unless existing_variant(spec_file).present?
      command =
        "gem install #{name} -v #{version} -i #{gems_path} --no-document --ignore-dependencies --no-user-install"
      command += " --source #{opts[:source]}" if opts[:source]
      puts command

      Bundler.with_unbundled_env { puts `#{command}` }
    end

    spec_file_variant = existing_variant(spec_file)
    if spec_file_variant.present?
      Gem.path << gems_path
      Gem::Specification.load(spec_file_variant).activate

      require opts[:require_name] ? opts[:require_name] : name unless opts[:require] == false
    else
      puts "You are specifying the gem #{name} in #{path}, however it does not exist!"
      puts "Looked for: #{spec_file} and #{spec_file_variant}"
      exit(-1)
    end
  end

  def self.existing_variant(spec_file)
    platform_less = "#{spec_file}.gemspec"
    return platform_less if File.exist? platform_less

    platform_full = "#{spec_file}-#{RUBY_PLATFORM}.gemspec"
    return platform_full if File.exist? platform_full

    platform_version_less =
      "#{spec_file}-#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}.gemspec"
    return platform_version_less if File.exist? platform_version_less

    nil
  end
end
