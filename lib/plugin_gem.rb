# frozen_string_literal: true

module PluginGem
  def self.load(path, name, version, opts = nil)
    opts ||= {}

    gems_path = File.dirname(path) + "/gems/#{RUBY_VERSION}"

    spec_path = gems_path + "/specifications"

    spec_file = spec_path + "/#{name}-#{version}"

    if platform_variants(spec_file).find(&File.method(:exist?)).blank?
      command =
        "gem install #{name} -v #{version} -i #{gems_path} --no-document --ignore-dependencies --no-user-install"
      command += " --source #{opts[:source]}" if opts[:source]
      puts command

      Bundler.with_unbundled_env { puts `#{command}` }
    end

    spec_file_variant = platform_variants(spec_file).find(&File.method(:exist?))
    if spec_file_variant.present?
      Gem.path << gems_path
      Gem::Specification.load(spec_file_variant).activate

      require opts[:require_name] ? opts[:require_name] : name unless opts[:require] == false
    else
      puts "You are specifying the gem #{name} in #{path}, however it does not exist!"
      puts "Looked for: \n- #{platform_variants(spec_file).join("\n- ")}"
      exit(-1)
    end
  end

  def self.platform_variants(spec_file)
    platform_less = "#{spec_file}.gemspec"

    platform_full = "#{spec_file}-#{RUBY_PLATFORM}.gemspec"

    platform_version_less =
      "#{spec_file}-#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}.gemspec"

    [platform_less, platform_full, platform_version_less]
  end
end
