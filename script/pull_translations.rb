# This script pulls translation files from Transifex and ensures they are in the format we need.
# You need the Transifex client installed.
# http://docs.transifex.com/developer/client/setup
#
# Don't use this script to create pull requests. Do translations in Transifex. The Discourse
# team will pull them in.

require 'open3'

if `which tx`.strip.empty?
  puts "", "The Transifex client needs to be installed to use this script."
  puts "Instructions are here: http://docs.transifex.com/developer/client/setup"
  puts "", "On Mac:", ""
  puts "  curl -O https://raw.github.com/pypa/pip/master/contrib/get-pip.py"
  puts "  sudo python get-pip.py"
  puts "  sudo pip install transifex-client", ""
  exit 1
end

puts "Pulling new translations...", ""

command = "tx pull --mode=developer #{ARGV.include?('force') ? '-f' : ''}"

Open3.popen2e(command) do |stdin, stdout_err, wait_thr|
  while line = stdout_err.gets
    puts line
  end
end
puts ""

unless $?.success?
  puts "Something failed. Check the output above.", ""
  exit $?.exitstatus
end

YML_FILE_COMMENTS = <<END
# encoding: utf-8
#
# Never edit this file. It will be overwritten when translations are pulled from Transifex.
#
# To work with us on translations, join this project:
# https://www.transifex.com/projects/p/discourse-org/
END

ALL_LOCALES = Dir.glob( File.expand_path("../../config/locales/client.*.yml", __FILE__) ).map {|x| x.split('.')[-2]}.sort

LOCALE_MAPPINGS = [['fr', 'fr_FR'],
                   ['es', 'es_ES'],
                   ['pt', 'pt_PT'],
                   ['ko', 'ko_KR']]

YML_DIRS = ['config/locales',
            'plugins/poll/config/locales',
            'vendor/gems/discourse_imgur/lib/discourse_imgur/locale']

# Change root element in yml files for some languages because Transifex uses a different
# locale code.
LOCALE_MAPPINGS.each do |ours, theirs|
  ['client', 'server'].each do |base|
    YML_DIRS.each do |dir|
      contents = []
      file_name = File.expand_path("../../#{dir}/#{base}.#{ours}.yml", __FILE__)
      found = false
      next unless File.exists?(file_name)
      File.open(file_name, 'r') do |file|
        file.each_line do |line|
          if found or line.strip != "#{theirs}:"
            contents << line
          else
            contents << "#{ours}:"
            found = true
          end
        end
      end

      File.open(file_name, 'w+') do |f|
        f.puts(YML_FILE_COMMENTS, '') unless contents[0][0] == '#'
        f.puts contents
      end
    end
  end
end

# Add comments to the top of files
(ALL_LOCALES - LOCALE_MAPPINGS.map(&:first)).each do |locale|
  ['client', 'server'].each do |base|
    YML_DIRS.each do |dir|
      file_name = File.expand_path("../../#{dir}/#{base}.#{locale}.yml", __FILE__)
      next unless File.exists?(file_name)
      contents = File.readlines(file_name)
      File.open(file_name, 'w+') do |f|
        f.puts(YML_FILE_COMMENTS, '') unless contents[0][0] == '#'
        f.puts contents
      end
    end
  end
end
