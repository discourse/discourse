# frozen_string_literal: true

module PluginGem
  def self.load(path, name, version, opts = nil)
    opts ||= {}

    gems_path = File.dirname(path) + "/gems/#{RUBY_VERSION}"

    spec_path = gems_path + "/specifications"

    spec_file  = spec_path + "/#{name}-#{version}"
    spec_file += "-#{opts[:platform]}" if opts[:platform]
    spec_file += ".gemspec"

    unless File.exist? spec_file
      command  = "gem install #{name} -v #{version} -i #{gems_path} --no-document --ignore-dependencies --no-user-install"
      command += " --source #{opts[:source]}" if opts[:source]
      puts command
      puts `#{command}`
    end

    if File.exist? spec_file
      Gem.path << gems_path
      Gem::Specification.load(spec_file).activate

      unless opts[:require] == false
        require opts[:require_name] ? opts[:require_name] : name
      end
    else
      puts "You are specifying the gem #{name} in #{path}, however it does not exist!"
      puts "Looked for: #{spec_file}"
      exit(-1)
    end
  end
end
