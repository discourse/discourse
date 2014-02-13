desc 'export the database'
task 'export', [:output_filename] => :environment do |t, args|
  puts 'Starting export...'
  output_filename = Jobs::Exporter.new.execute( format: :json, filename: args.output_filename )
  puts 'Export done.'
  puts "Output file is in: #{output_filename}", ''
end

desc 'import from an export file and replace the contents of the current database'
task 'import', [:input_filename] => :environment do |t, args|
  puts 'Starting import...'
  begin
    Jobs::Importer.new.execute( format: :json, filename: args.input_filename )
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
  num_backup_tables = Import::backup_tables_count

  if User.exec_sql("select count(*) as count from information_schema.schemata where schema_name = 'backup'")[0]['count'].to_i <= 0
    puts "Backup tables don't exist!  An import was never performed or the backup tables were dropped.", "Rollback cancelled."
  elsif num_backup_tables != Export.models_included_in_export.size
    puts "Expected #{Export.models_included_in_export.size} backup tables, but there are #{num_backup_tables}!", "Rollback cancelled."
  else
    puts 'Starting rollback..'
    Jobs::Importer.new.rollback
    puts 'Rollback done.'
  end
end

desc 'After a successful import, drop the backup tables'
task 'import:remove_backup' => :environment do |t|
  if Import::backup_tables_count > 0
    User.exec_sql("DROP SCHEMA IF EXISTS #{Jobs::Importer::BACKUP_SCHEMA} CASCADE")
    puts "Backup tables dropped successfully."
  else
    puts "No backup found. Nothing was done."
  end
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
