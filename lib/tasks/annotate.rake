# frozen_string_literal: true

# Runs annotaterb in a TemporaryDb so the index setup performed by
# `annotate:ensure_all_indexes` does not leak into the persistent test DB.
def annotate_in_temp_db(load_plugins:, annotaterb_args: [])
  env = {
    "RAILS_ENV" => "test",
    "LOAD_PLUGINS" => load_plugins,
    "SKIP_OPTIMIZE_ICONS" => "1",
    "SKIP_SEED_FU" => "1",
  }
  db = TemporaryDb.new(port: ENV["TEMPORARY_DB_PORT"]&.to_i)
  db.start
  db.with_env do
    system(env, "bin/rails", "db:migrate", "annotate:ensure_all_indexes", exception: true)
    system(env, "bin/annotaterb", "models", "--force", *annotaterb_args, exception: true)
  end
ensure
  db&.stop
  db&.remove
end

desc "ensure the asynchronously-created post_search_data index is present"
task "annotate" => :environment do |task, args|
  system("bin/annotaterb models", exception: true)
  STDERR.puts "Annotate executed successfully"

  non_core_plugins =
    Dir["plugins/*"].filter { |plugin_path| `git check-ignore #{plugin_path}`.present? }
  if non_core_plugins.length > 0
    STDERR.puts "Warning: you have non-core plugins installed which may affect the annotations"
    STDERR.puts "For core annotations, consider running `bin/rails annotate:clean`"
  end
end

desc "ensure the asynchronously-created post_search_data index is present"
task "annotate:ensure_all_indexes" => :environment do |task, args|
  recent_posts_size = SiteSetting.search_recent_posts_size
  offset_size = SiteSetting.search_enable_recent_regular_posts_offset_size
  offset_post_id = SiteSetting.search_recent_regular_posts_offset_post_id
  inserted_synthetic_row = false

  # One of the indexes on post_search_data is created by a sidekiq job.
  # Add the minimum data needed to create it on demand.
  begin
    PostSearchData.insert_all!([{ post_id: 0, private_message: false }])
    inserted_synthetic_row = true
    SiteSetting.search_enable_recent_regular_posts_offset_size = 1
    SiteSetting.search_recent_posts_size = 1
    Jobs::CreateRecentPostSearchIndexes.new.execute([])
  ensure
    PostSearchData.where(post_id: 0).delete_all if inserted_synthetic_row
    SiteSetting.search_enable_recent_regular_posts_offset_size = offset_size
    SiteSetting.search_recent_posts_size = recent_posts_size
    SiteSetting.search_recent_regular_posts_offset_post_id = offset_post_id
  end
end

desc "regenerate core model annotations using a temporary database"
task "annotate:clean" => :environment do |task, args|
  load_plugins = ENV["LOAD_PLUGINS"].presence || bundled_plugins_list
  model_dir = ENV["MODEL_DIR"].presence || "app/models"
  annotate_in_temp_db(load_plugins: load_plugins, annotaterb_args: ["--model-dir", model_dir])
  STDERR.puts "Annotate executed successfully"
end

def bundled_plugins_list
  require "open3"
  output, status = Open3.capture2("script/list_bundled_plugins")
  raise "script/list_bundled_plugins failed (#{status.exitstatus})" unless status.success?
  output.split("\n").map { |p| File.basename(p.strip) }.reject(&:empty?).join(",")
end

desc "regenerate plugin model annotations using a temporary database"
task "annotate:clean:plugins", [:plugin] => :environment do |task, args|
  annotaterb_args = []
  if args[:plugin].present?
    annotaterb_args.push("--model-dir", "plugins/#{args[:plugin]}/app/models")
  end
  annotate_in_temp_db(load_plugins: "1", annotaterb_args: annotaterb_args)
  STDERR.puts "Annotate executed successfully"
end
