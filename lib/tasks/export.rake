desc 'export the database'
task 'export', [:output_filename] => :environment do |t, args|
  require "backup_restore"
  require "export/exporter"

  puts "Starting export..."
  backup = Export::Exporter.new(Discourse.system_user.id).run
  if args.output_filename.present?
    puts "Moving '#{backup}' to '#{args.output_filename}'"
    FileUtils.mv(backup, args.output_filename)
    backup = args.output_filename
  end
  puts "Export done."
  puts "Output file is in: #{backup}", ""
end

desc 'import from an export file and replace the contents of the current database'
task 'import', [:input_filename] => :environment do |t, args|
  require "backup_restore"
  require "import/importer"

  begin
    puts 'Starting import...'
    Import::Importer.new(Discourse.system_user.id, args.input_filename).run
    puts 'Import done.'
  rescue Import::FilenameMissingError
    puts '', 'The filename argument was missing.', '', 'Usage:', ''
    puts '  rake import[/path/to/export.json.gz]', ''
  rescue Import::ImportDisabledError
    puts '', 'Imports are not allowed.', 'An admin needs to set allow_restore to true in the site settings before imports can be run.', ''
    puts 'Import cancelled.', ''
  end
end

desc 'After a successful import, restore the backup tables'
task 'import:rollback' => :environment do |t|
  puts 'Rolling back if needed..'
  require "backup_restore"
  BackupRestore.rollback!
  puts 'Done.'
end

desc 'Allow imports'
task 'import:enable' => :environment do |t|
  SiteSetting.allow_restore = true
  puts 'Imports are now permitted.  Disable them with rake import:disable'
end

desc 'Forbid imports'
task 'import:disable' => :environment do |t|
  SiteSetting.allow_restore = false
  puts 'Imports are now forbidden.'
end
