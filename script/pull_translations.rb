# This script pulls translation files from Transifex and ensures they are in the format we need.
# You need the Transifex client installed.
# http://docs.transifex.com/developer/client/setup
#
# Don't use this script to create pull requests. Do translations in Transifex. The Discourse
# team will pull them in.

require 'open3'

if `which tx`.strip.empty?
  puts '', 'The Transifex client needs to be installed to use this script.'
  puts 'Instructions are here: http://docs.transifex.com/developer/client/setup'
  puts '', 'On Mac:', ''
  puts '  curl -O https://raw.github.com/pypa/pip/master/contrib/get-pip.py'
  puts '  sudo python get-pip.py'
  puts '  sudo pip install transifex-client', ''
  exit 1
end

locales = Dir.glob(File.expand_path('../../config/locales/client.*.yml', __FILE__)).map {|x| x.split('.')[-2]}.select {|x| x != 'en'}.sort.join(',')

puts 'Pulling new translations...', ''
command = "tx pull --mode=developer --language=#{locales} #{ARGV.include?('force') ? '-f' : ''}"

Open3.popen2e(command) do |stdin, stdout_err, wait_thr|
  while (line = stdout_err.gets)
    puts line
  end
end
puts ''

unless $?.success?
  puts 'Something failed. Check the output above.', ''
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

YML_DIRS = ['config/locales',
            'plugins/poll/config/locales',
            'vendor/gems/discourse_imgur/lib/discourse_imgur/locale']

# Add comments to the top of files
['client', 'server'].each do |base|
  YML_DIRS.each do |dir|
    Dir.glob(File.expand_path("../../#{dir}/#{base}.*.yml", __FILE__)).each do |file_name|
      language = File.basename(file_name).match(Regexp.new("#{base}\\.([^\\.]*)\\.yml"))[1]

      lines = File.readlines(file_name)
      lines.collect! {|line| line =~ /^[a-z_]+:$/i ? "#{language}:" : line}

      File.open(file_name, 'w+') do |f|
        f.puts(YML_FILE_COMMENTS, '') unless lines[0][0] == '#'
        f.puts(lines)
      end
    end
  end
end
