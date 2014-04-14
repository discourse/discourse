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
# TODO: The following tx command may need to always use "-f" to force pull all translations.
#       I don't understand how it decides to skip some files, but it seems to skip
#       even when there are new translations on the server sometimes.
Open3.popen2e('tx pull --mode=developer') do |stdin, stdout_err, wait_thr|
  while line = stdout_err.gets
    puts line
  end
end
puts ""

if !$?.success?
  puts "Something failed. Check the output above.", ""
  exit $?.exitstatus
end

yml_file_comments = <<END
# encoding: utf-8
#
# Never edit this file. It will be overwritten when translations are pulled from Transifex.
#
# To work with us on translations, join this project:
# https://www.transifex.com/projects/p/discourse-pt-br/
END

# Change root element in yml files for some languages because Transifex uses a different
# locale code.
[['fr', 'fr_FR'], ['es', 'es_ES'], ['pt', 'pt_PT'], ['ko', 'ko_KR']].each do |ours, theirs|
  ['client', 'server'].each do |base|
    contents = []
    file_name = File.expand_path("../../config/locales/#{base}.#{ours}.yml", __FILE__)
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
      f.puts(yml_file_comments, '') unless contents[0][0] == '#'
      f.puts contents
    end
  end
end

(Dir.glob( File.expand_path("../../config/locales/client.*.yml", __FILE__) ).map {|x| x.split('.')[-2]}.sort - ['fr', 'es', 'pt', 'ko']).each do |locale|
  ['client', 'server'].each do |base|
    file_name = File.expand_path("../../config/locales/#{base}.#{locale}.yml", __FILE__)
    next unless File.exists?(file_name)
    contents = File.readlines(file_name)
    File.open(file_name, 'w+') do |f|
      f.puts(yml_file_comments, '') unless contents[0][0] == '#'
      f.puts contents
    end
  end
end
