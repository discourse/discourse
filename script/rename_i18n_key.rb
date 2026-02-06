# frozen_string_literal: true

require "yaml"

class YamlKeyRenamer
  INDENT_STEP = 2

  KEY_LINE_REGEX =
    /
    ^(\s*)                                    # leading indent
    ("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^\s#:][^:]*?)  # key (quoted or unquoted)
    \s*:
  /x.freeze

  def initialize(file, old_key, new_key)
    @english_file = file
    @old_key = old_key
    @new_key = new_key
    @old_parts = old_key.split(".")
    @new_parts = new_key.split(".")
  end

  def run
    validate!

    locale = detect_locale(@english_file)
    lines = File.readlines(@english_file)

    if !find_key_line(lines, @old_parts, locale)
      abort "Error: Key '#{@old_key}' not found in #{@english_file}"
    end

    if find_key_line(lines, @new_parts, locale)
      abort "Error: Key '#{@new_key}' already exists in #{@english_file}"
    end

    puts "Renaming key in locale files:"
    puts "  #{@old_key} → #{@new_key}"
    puts

    modified = 0
    total = 0

    all_files = [@english_file] + find_sibling_locales
    all_files.each do |file|
      total += 1
      loc = detect_locale(file)
      file_lines = File.readlines(file)

      unless find_key_line(file_lines, @old_parts, loc)
        puts "  - #{file} (key not found, skipping)"
        next
      end

      begin
        if simple_rename?
          rename_in_file(file, loc)
        else
          move_in_file(file, loc)
        end
        puts "  ✓ #{file}"
        modified += 1
      rescue StandardError => err
        puts "  ✗ #{file} (#{err.message})"
      end
    end

    puts
    puts "Done! Renamed key in #{modified} of #{total} locale files."
  end

  private

  def validate!
    abort "Error: File '#{@english_file}' not found" unless File.exist?(@english_file)
    abort "Error: OLD_KEY and NEW_KEY must differ" if @old_key == @new_key
  end

  def simple_rename?
    !@new_key.include?(".")
  end

  def detect_locale(file)
    match = File.basename(file).match(/\.([^.]+)\.yml$/)
    abort "Error: Locale could not be detected from filename '#{file}'" unless match
    match[1]
  end

  def find_sibling_locales
    dir = File.dirname(@english_file)
    basename = File.basename(@english_file)
    pattern = basename.sub(".en.", ".*.").sub(".en_", ".*_")
    # Handle both .en. and locale patterns
    pattern = basename.sub(/\.en([\._])/, '.*\1') if pattern == basename
    Dir[File.join(dir, pattern)].reject { |f| f == @english_file }.sort
  end

  def find_key_line(lines, key_parts, locale)
    target = [locale] + key_parts
    current_path = []

    lines.each_with_index do |line, idx|
      parsed = parse_key_line(line)
      next unless parsed

      depth, key = parsed
      current_path = current_path[0...depth]
      current_path[depth] = key

      return idx if current_path == target
    end
    nil
  end

  def parse_key_line(line)
    return nil if line.strip.empty? || line.strip.start_with?("#")

    match = line.match(KEY_LINE_REGEX)
    return nil unless match

    indent = match[1].length
    depth = indent / INDENT_STEP
    raw_key = match[2].strip
    key = raw_key.delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'")
    [depth, key]
  end

  def detect_block_range(lines, key_line)
    key_indent = lines[key_line][/^\s*/].length
    end_line = key_line

    ((key_line + 1)...lines.length).each do |i|
      line = lines[i]
      next if line.strip.empty?
      break if line[/^\s*/].length <= key_indent
      end_line = i
    end

    [key_line, end_line]
  end

  def rename_in_file(file, locale)
    lines = File.readlines(file)
    original = lines.join

    key_line = find_key_line(lines, @old_parts, locale)
    return unless key_line

    old_leaf = @old_parts.last
    new_leaf = @new_key

    line = lines[key_line]
    # Handle quoted and unquoted keys
    lines[key_line] = replace_key_on_line(line, old_leaf, new_leaf)

    write_and_validate(file, lines, original)
  end

  def move_in_file(file, locale)
    lines = File.readlines(file)
    original = lines.join

    key_line = find_key_line(lines, @old_parts, locale)
    return unless key_line

    start_line, end_line = detect_block_range(lines, key_line)
    extracted = lines[start_line..end_line]
    old_indent = lines[start_line][/^\s*/].length

    # Remove extracted lines
    lines.slice!(start_line..end_line)

    # Remove trailing blank line left behind if present
    lines.delete_at(start_line) if start_line < lines.length && lines[start_line]&.strip&.empty?

    insertion = find_insertion_point(lines, @new_parts[0...-1], locale)
    new_indent = insertion[:indent] + INDENT_STEP

    missing_lines = []
    current_indent = insertion[:indent] + INDENT_STEP
    insertion[:missing_keys].each do |mk|
      missing_lines << "#{" " * current_indent}#{format_key(mk)}:\n"
      current_indent += INDENT_STEP
    end
    new_indent = current_indent

    # Adjust extracted block indentation
    adjusted = adjust_indent(extracted, old_indent, new_indent)

    # Replace the old leaf key name with the new one on the first line
    old_leaf = @old_parts.last
    new_leaf = @new_parts.last
    adjusted[0] = replace_key_on_line(adjusted[0], old_leaf, new_leaf) if old_leaf != new_leaf

    insert_at = insertion[:line] + 1
    lines.insert(insert_at, *(missing_lines + adjusted))

    write_and_validate(file, lines, original)
  end

  def find_insertion_point(lines, parent_parts, locale)
    full_path = [locale] + parent_parts
    current_path = []
    deepest_match = 0
    deepest_line = 0
    deepest_indent = -INDENT_STEP

    lines.each_with_index do |line, idx|
      parsed = parse_key_line(line)
      next unless parsed

      depth, key = parsed
      indent = depth * INDENT_STEP
      current_path = current_path[0...depth]
      current_path[depth] = key

      match_len = 0
      full_path.each_with_index do |part, i|
        break unless current_path[i] == part
        match_len = i + 1
      end

      if match_len > deepest_match
        deepest_match = match_len
        deepest_line = idx
        deepest_indent = indent
      end
    end

    if deepest_match > 0
      _, last_line = detect_block_range(lines, deepest_line)
      missing = full_path[deepest_match..]
      { line: last_line, indent: deepest_indent, missing_keys: missing }
    else
      { line: lines.length - 1, indent: -INDENT_STEP, missing_keys: full_path }
    end
  end

  def adjust_indent(extracted_lines, old_indent, new_indent)
    diff = new_indent - old_indent
    extracted_lines.map do |line|
      if line.strip.empty?
        line
      elsif diff > 0
        (" " * diff) + line
      elsif diff < 0
        # Remove leading spaces, but don't go negative
        current = line[/^\s*/].length
        new_len = [current + diff, 0].max
        " " * new_len + line.lstrip
      else
        line
      end
    end
  end

  def replace_key_on_line(line, old_key, new_key)
    formatted_new = format_key(new_key)
    escaped_old = Regexp.escape(old_key)
    key_capture = /("#{escaped_old}"|'#{escaped_old}'|#{escaped_old})(\s*:)/

    line
      .sub(/(?<=\s)#{key_capture.source}/) { "#{formatted_new}#{Regexp.last_match(2)}" }
      .sub(/^#{key_capture.source}/) { "#{formatted_new}#{Regexp.last_match(2)}" }
  end

  def format_key(key)
    # Quote keys that contain special characters
    if key.match?(/[\-\s\[\]{}:,&*?|>!%@`#]/) || key.match?(/\A[0-9]/) ||
         %w[true false null yes no].include?(key.downcase)
      %("#{key}")
    else
      key
    end
  end

  def write_and_validate(file, lines, original)
    content = lines.join
    File.write(file, content)

    # Validate YAML is still parseable
    YAML.safe_load(content, permitted_classes: [Symbol], aliases: true)
  rescue Psych::SyntaxError => err
    # Restore original content
    File.write(file, original)
    raise "YAML validation failed after modification (restored original): #{err.message}"
  end
end

if __FILE__ == $PROGRAM_NAME
  require "thor"

  class RenameI18nKeyCLI < Thor
    default_task :rename

    def self.start(given_args = ARGV, config = {})
      if given_args.length == 3 && !all_tasks.key?(given_args[0])
        given_args = ["rename", *given_args]
      end
      super(given_args, config)
    end

    desc "rename FILE OLD_KEY NEW_KEY", "Rename or move a YAML key across all locale files."
    long_desc <<~LONG
      Arguments:
        FILE      English locale file path (e.g. config/locales/server.en.yml)
        OLD_KEY   Dot-separated YAML path, excluding locale prefix
        NEW_KEY   Leaf name (simple rename) or full dot path (move)

      Examples:
        # Simple rename (fix typo):
        ruby script/rename_i18n_key.rb config/locales/server.en.yml post_action_types.inappropriate.tittle title

        # Move to new path:
        ruby script/rename_i18n_key.rb config/locales/server.en.yml post_action_types.old.title post_action_types.new.title

        # Plugin file:
        ruby script/rename_i18n_key.rb plugins/poll/config/locales/client.en.yml js.poll.voters js.poll.votes
    LONG
    def rename(file, old_key, new_key)
      YamlKeyRenamer.new(file, old_key, new_key).run
    end
  end

  RenameI18nKeyCLI.start
end
