require "optparse"
require_relative "refactorers/refactor_where_first_to_find_by.rb"
require_relative "refactorers/refactor_where_first_not_called_expectations.rb"
require_relative "refactorers/refactor_where_first_mocks.rb"
require_relative "refactorers/refactor_where_first_strict_mocks.rb"

options = { overwrite: true }
OptionParser.new do |opts|
  opts.banner = "Usage: refactorer.rb [options]"

  opts.on("-d", "--dry-run", "Write changes to console, rather than to source files.") do |v|
    options[:overwrite] = false
  end
end.parse!

source_dir = ARGV.first || "."
base = File.expand_path(File.join("**", "*.rb"), source_dir)
puts "Refactoring in source directory: #{base}"

[
  # Refactor "where(...).first -> find_by(...)"
  RefactorWhereFirstToFindBy,

  # Refactor ".expect(:where).never" to ".expect(:find_by).never"
  RefactorWhereFirstNotCalledExpectations,

  # Refactor ".expect(:where).return([X])" to ".expect(:find_by).return(X)"
  #      and ".stubs(:where).return([X])" to ".stubs(:find_by).return(X)"
  RefactorWhereFirstMocks,

  # Refactor ".expect(:where).with(...).return([X])" to ".expect(:find_by).with(...).return(X)"
  RefactorWhereFirstStrictMocks

].each do |refactorer|
  refactorer.new.refactor_files(Dir.glob(base)) do |path, refactored, changes|
    if changes.empty?
      puts "No changes in #{path}"

    else
      puts "In #{path}:"

      changes.each do |change|
        puts "\tAt #{change.original_position}, inserting:\n\t\t#{change.refactored_code}"
        puts ""
      end

      File.open(path, "w") { |f| f.write(refactored) } if options[:overwrite]
    end
  end
end
