desc 'Export all the categories'
task 'export:categories', [:category_ids] => [:environment] do |_, args|
  require "import_export/import_export"

  ImportExport.export_categories(args[:category_ids])
  puts "", "Done", ""
end

desc 'Export only the structure of all categories'
task 'export:category_structure', [:include_group_users, :file_name] => [:environment] do |_, args|
  require "import_export/import_export"

  ImportExport.export_category_structure(args[:include_group_users], args[:file_name])
  puts "", "Done", ""
end
