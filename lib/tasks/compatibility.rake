# frozen_string_literal: true

desc "validate a discourse-compatibility file"
task "compatibility:validate", %i[path] => :environment do |t, args|
  path = args[:path]

  class CoreTooRecentError < StandardError
  end

  def fail!(msg, error)
    puts <<~MSG
        --- FAILURE ---
        #{msg.strip}
        ---------------
      MSG
    raise error
  end

  puts "Current Discourse Version: #{::Discourse::VERSION::STRING}"
  puts "Checking validity of #{path}"

  content = File.read(path)
  begin
    result = Discourse.find_compatible_resource(content)

    puts "File parsed successfully"

    fail! <<~MSG, CoreTooRecentError if result
        Compatibility file has an entry which matches the current version of Discourse core.
        This is not allowed - compatibility files should only be used for older core versions
      MSG
  rescue Discourse::InvalidVersionListError => e
    fail! "Invalid version list", e
  end

  puts "Compatibility file is valid"
end
