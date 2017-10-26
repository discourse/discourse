desc 'Export all the categories'
task 'export:categories', [:include_group_users, :file_name] => [:environment] do |_, args|
  require "import_export/import_export"

  ImportExport.export_categories(args[:include_group_users], args[:file_name])
  puts "", "Done", ""
end
