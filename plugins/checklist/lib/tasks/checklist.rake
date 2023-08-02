# frozen_string_literal: true

desc "Convert old style checkbox markdown to new style"
task "discourse_checklist:migrate_old_syntax" => :environment do |t|
  puts "Updating checklist syntax on all posts..."

  Post
    .raw_match("[")
    .find_each(batch_size: 50) { |post| ChecklistSyntaxMigrator.new(post).update_syntax! }

  puts "", "Done!"
end
