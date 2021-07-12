# frozen_string_literal: true

desc "generate a release note from the important commits"
task "release_note:generate", :from, :to, :repo do |t, args|
  repo = args[:repo] || "."
  from = args[:from] || `git -C #{repo} describe --tags --abbrev=0`.strip
  to = args[:to] || "HEAD"

  bug_fixes = Set.new
  new_features = Set.new
  ux_changes = Set.new
  sec_changes = Set.new
  perf_changes = Set.new
  a11y_changes = Set.new

  out = `git -C #{repo} log --pretty="tformat:%s" '#{from}..#{to}'`
  next "Status #{$?.exitstatus} running git log\n#{out}" if !$?.success?

  out.each_line do |comment|
    next if comment =~ /^\s*Revert/
    split_comments(comment).each do |line|
      if line =~ /^FIX:/
        bug_fixes << better(line)
      elsif line =~ /^FEATURE:/
        new_features << better(line)
      elsif line =~ /^UX:/
        ux_changes << better(line)
      elsif line =~ /^SECURITY:/
        sec_changes << better(line)
      elsif line =~ /^PERF:/
        perf_changes << better(line)
      elsif line =~ /^A11Y:/
        a11y_changes << better(line)
      end
    end
  end

  print_changes("New Features", new_features)
  print_changes("Bug Fixes", bug_fixes)
  print_changes("UX Changes", ux_changes)
  print_changes("Security Changes", sec_changes)
  print_changes("Performance", perf_changes)
  print_changes("Accessibility", a11y_changes)

  if [bug_fixes, new_features, ux_changes, sec_changes, perf_changes, a11y_changes].all?(&:empty?)
    puts "(no changes)", ""
  end
end

# To use with all-the-plugins:
#  1. Make sure you have a local, up-to-date clone of https://github.com/discourse/all-the-plugins
#  2. In all-the-plugins, `git submodule update --init --recursive --remote`
#  3. Change back to your discourse directory
#  4. rake "release_note:plugins:generate[ HEAD@{2021-06-01} , HEAD@{now} , /path/to/all-the-plugins/plugins/* , discourse ]"
desc "generate release notes for all official plugins in a directory"
task "release_note:plugins:generate", :from, :to, :plugin_glob, :org do |t, args|
  from = args[:from]
  to = args[:to]
  plugin_glob = args[:plugin_glob] || "./plugins/*"
  git_org = args[:org]

  all_repos = Dir.glob(plugin_glob).filter { |f| File.directory?(f) && File.exists?("#{f}/.git")  }

  if git_org
    all_repos = all_repos.filter { |dir| `git -C #{dir} remote get-url origin`.match?(/github.com[\/:]#{git_org}\//) }
  end

  all_repos.each do |dir|
    puts "## #{File.basename(dir)}\n\n"
    Rake::Task["release_note:generate"].invoke(from, to, dir)
    Rake::Task["release_note:generate"].reenable
    puts "---", ""
  end
end

def print_changes(heading, changes)
  return if changes.length == 0

  puts "### #{heading}", ""
  puts changes.to_a, ""
end

def better(line)
  line = remove_prefix(line)
  line = escape_brackets(line)
  line = remove_pull_request(line)
  line[0] = '\#' if line[0] == '#'
  if line[0]
    line[0] = line[0].capitalize
    "- " + line
  else
    nil
  end
end

def remove_prefix(line)
  line.gsub(/^(FIX|FEATURE|UX|SECURITY|PERF|A11Y):/, "").strip
end

def escape_brackets(line)
  line.gsub("<", "`<")
    .gsub(">", ">`")
    .gsub("[", "`[")
    .gsub("]", "]`")
end

def remove_pull_request(line)
  line.gsub(/ \(\#\d+\)$/, "")
end

def split_comments(text)
  text = normalize_terms(text)
  terms = ["FIX:", "FEATURE:", "UX:", "SECURITY:" , "PERF:" , "A11Y:"]
  terms.each do |term|
    text = text.gsub(/(#{term})+/i, term)
    text = newlines_at_term(text, term)
  end
  text.split("\n")
end

def normalize_terms(text)
  text = text.gsub(/(BUGFIX|FIX|BUG):/i, "FIX:")
  text = text.gsub(/FEATURE:/i, "FEATURE:")
  text = text.gsub(/(UX|UI):/i, "UX:")
  text = text.gsub(/(SECURITY):/i, "SECURITY:")
  text = text.gsub(/(PERF):/i, "PERF:")
  text = text.gsub(/(A11Y):/i, "A11Y:")
end

def newlines_at_term(text, term)
  if text.include?(term)
    text = text.split(term).map { |l| l.strip }.join("\n#{term} ")
  end
  text
end
