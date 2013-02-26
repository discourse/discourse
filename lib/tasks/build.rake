desc "stamp the current build with the git hash placed in version.rb"
task "build:stamp" => :environment do
  git_version = `git rev-parse HEAD`.strip
  File.open(Rails.root.to_s + '/config/version.rb', 'w') do |f|
    f.write("$git_version = #{git_version.inspect}\n")
  end
  puts "Stamped current build with #{git_version}"
end
