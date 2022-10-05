# frozen_string_literal: true

require 'yaml'

desc 'Exports locale overrides'
task 'locale_overrides:export', [:type] => [:environment] do |_, args|
  begin
    h = LocaleOverridesTask.export_to_hash(args[:type])
    puts h.to_yaml
  rescue => e
    STDERR.puts e
  end
end
