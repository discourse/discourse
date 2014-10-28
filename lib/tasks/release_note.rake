desc "generate a release note from the important commits"
task "release_note:generate", :tag do |t, args|
  tag = args[:tag] || `git describe --tags --abbrev=0`.strip

  bug_fixes = Set.new
  new_features = Set.new
  ux_changes = Set.new

  `git log #{tag}..HEAD`.each_line do |comment|
    split_comments(comment).each do |line|
      if line =~ /^FIX:/
        bug_fixes << better(line)
      elsif line =~ /^FEATURE:/
        new_features << better(line)
      elsif line =~ /^UX:/
        ux_changes << better(line)
      end
    end
  end

  puts "NEW FEATURES:", "-------------", "", new_features.to_a, ""
  puts "BUG FIXES:", "----------", "", bug_fixes.to_a, ""
  puts "UX CHANGES:", "-----------", "", ux_changes.to_a, ""
end

def better(line)
  line = remove_prefix(line)
  line = escape_brackets(line)
  line[0] = '\#' if line[0] == '#'
  line[0] = line[0].capitalize
  "- " + line
end

def remove_prefix(line)
  line.gsub(/^(FIX|FEATURE|UX):/, "").strip
end

def escape_brackets(line)
  line.gsub("<", "`<")
      .gsub(">", ">`")
      .gsub("[", "`[")
      .gsub("]", "]`")
end

def split_comments(text)
  text = normalize_terms(text)
  terms = ["FIX:", "FEATURE:", "UX:"]
  terms.each do |term|
    text = newlines_at_term(text, term)
  end
  text.split("\n")
end

def normalize_terms(text)
  text = text.gsub(/(BUGFIX|FIX|BUG):/i, "FIX:")
  text = text.gsub(/FEATURE:/i, "FEATURE:")
  text = text.gsub(/UX:/i, "UX:")
end

def newlines_at_term(text, term)
  if text.include?(term)
    text = text.split(term).map{ |l| l.strip }.join("\n#{term} ")
  end
  text
end
