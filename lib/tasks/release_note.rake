desc "generate a release note from the important commits"
task "release_note:generate", :tag do |t, args|
  tag = args[:tag] || `git describe --tags --abbrev=0`.strip

  bug_fixes = Set.new
  new_features = Set.new
  ux_changes = Set.new

  `git log --pretty=format:%s #{tag}..HEAD`.each_line do |line|
    if line =~ /^(FIX|BUG|BUGFIX):/i
      bug_fixes << better(line)
    elsif line =~ /^FEATURE:/i
      new_features << better(line)
    elsif line =~ /^UX:/i
      ux_changes << better(line)
    end
  end

  puts "NEW FEATURES:", new_features.to_a, ""
  puts "BUG FIXES:", bug_fixes.to_a, ""
  puts "UX CHANGES:", ux_changes.to_a, ""

end

def better(line)
  line = line.gsub(/^(FIX|BUG|BUGFIX|FEATURE|UX):/i, "").strip
  line[0] = line[0].capitalize
  line
end
