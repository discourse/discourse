module PluginGem
  def self.load(path, name, version, opts = nil)
    opts ||= {}

    gems_path = File.dirname(path) + "/gems/#{RUBY_VERSION}"
    spec_path = gems_path + "/specifications"
    spec_file = spec_path + "/#{name}-#{version}.gemspec"
    unless File.exists? spec_file
      command = "gem install #{name} -v #{version} -i #{gems_path} --no-document --ignore-dependencies"
      if opts[:source]
        command << " --source #{opts[:source]}"
      end
      puts command
      puts `#{command}`
    end
    if File.exists? spec_file
      spec = Gem::Specification.load spec_file
      spec.activate
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
