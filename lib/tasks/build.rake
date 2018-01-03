desc "stamp the current build with the git hash placed in version.rb"
task "build:stamp" => :environment do
  git_version  = `git rev-parse HEAD`.strip
  git_branch   = `git rev-parse --abbrev-ref HEAD`
  full_version = `git describe --dirty --match "v[0-9]*"`

  File.open(Rails.root.to_s + '/config/version.rb', 'w') do |f|
    f.write("$git_version  = #{git_version.inspect}\n")
    f.write("$git_branch   = #{git_branch.inspect}\n")
    f.write("$full_version = #{full_version.inspect}\n")
  end
  puts "Stamped current build with #{git_version} #{git_branch} #{full_version}"
end
