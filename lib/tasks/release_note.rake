desc "generate a release note from the important commits"
task "release_note:generate", :tag do |t, args|
  tag = args[:tag] || `git describe --tags --abbrev=0`.strip

  bug_fixes = []
  new_features = []
  ux_changes = []

  `git log --pretty=format:%s #{tag}..HEAD`.each_line do |line|
    if line =~ /^(FIX|BUG|BUGFIX):/i
      bug_fixes << line
    elsif line =~ /^FEATURE:/i
      new_features << line
    elsif line =~ /^UX:/i
      ux_changes << line
    end
  end

  puts "NEW FEATURES:", new_features, ""
  puts "BUG FIXES:", bug_fixes, ""
  puts "UX CHANGES:", ux_changes, ""

end
