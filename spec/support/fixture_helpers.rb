# frozen_string_literal: true

# Materializes fixtures into a per-run temp directory that's safe across parallel workers.

class SpecSecureRandom
  class << self
    attr_accessor :value
  end
end

def concurrency_safe_tmp_dir
  SpecSecureRandom.value ||= SecureRandom.hex
  dir_path = File.join(Dir.tmpdir, "rspec_#{Process.pid}_#{SpecSecureRandom.value}")
  FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
  dir_path
end

def file_from_fixtures(
  filename,
  directory = "images",
  root_path = "#{Rails.root.join("spec/fixtures")}"
)
  tmp_file_path = File.join(concurrency_safe_tmp_dir, SecureRandom.hex << filename)
  FileUtils.cp("#{root_path}/#{directory}/#{filename}", tmp_file_path)
  File.new(tmp_file_path)
end

def plugin_file_from_fixtures(filename, directory = "images")
  # We [1] here instead of [0] because the first caller is the current method.
  #
  # /home/mb/repos/discourse-ai/spec/lib/modules/ai_bot/tools/discourse_meta_search_spec.rb:17:in `block (2 levels) in <main>'
  first_non_gem_caller = caller_locations.select { |loc| !loc.to_s.match?(/gems/) }[1]&.path
  raise StandardError.new("Could not find caller for fixture #{filename}") if !first_non_gem_caller

  # This is the full path of the plugin spec file that needs a fixture.
  # realpath makes sure we follow symlinks.
  #
  # #<Pathname:/home/mb/repos/discourse-ai/spec/lib/modules/ai_bot/tools/discourse_meta_search_spec.rb>
  plugin_caller_path = Pathname.new(first_non_gem_caller).realpath

  plugin_match =
    Discourse.plugins.find do |plugin|
      # realpath makes sure we follow symlinks
      plugin_caller_path.to_s.starts_with?(Pathname.new(plugin.root_dir).realpath.to_s)
    end

  if !plugin_match
    raise StandardError.new(
            "Could not find matching plugin for #{plugin_caller_path} and fixture #{filename}",
          )
  end

  file_from_fixtures(filename, directory, "#{plugin_match.root_dir}/spec/fixtures")
end

def file_from_contents(contents, filename, directory = "images")
  tmp_file_path = File.join(concurrency_safe_tmp_dir, SecureRandom.hex << filename)
  File.write(tmp_file_path, contents)
  File.new(tmp_file_path)
end

def plugin_from_fixtures(plugin_name)
  tmp_plugins_dir = File.join(concurrency_safe_tmp_dir, "plugins")

  FileUtils.mkdir(tmp_plugins_dir) if !Dir.exist?(tmp_plugins_dir)
  FileUtils.cp_r("#{Rails.root.join("spec/fixtures/plugins/#{plugin_name}")}", tmp_plugins_dir)

  Plugin::Instance.parse_from_source(File.join(tmp_plugins_dir, plugin_name, "plugin.rb"))
end

RSpec.configure do |config|
  config.after(:suite) do
    FileUtils.remove_dir(concurrency_safe_tmp_dir, true) if SpecSecureRandom.value
  end
end
