# frozen_string_literal: true

require_relative "../../../../config/environment"
require_relative "../../native_upload_store"

begin
  settings = YAML.safe_load_file(ARGV.fetch(0), symbolize_names: true)
  puts JSON.generate(
         BulkImport::NativeUploadStore.resolve_target(
           settings.fetch(:site_settings),
           read_prefixes: settings.fetch(:preupload_read_prefixes, {}),
         ),
       )
rescue Psych::Exception
  abort "Invalid private uploader YAML"
end
