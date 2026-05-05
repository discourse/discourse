# frozen_string_literal: true

# Runs annotaterb in a TemporaryDb so the seed topics that
# `annotate:ensure_all_indexes` creates don't leak into the persistent test DB.
def annotate_in_temp_db(load_plugins:, annotaterb_args: "")
  env = "RAILS_ENV=test LOAD_PLUGINS=#{load_plugins}"
  db = TemporaryDb.new
  db.start
  db.with_env do
    system("#{env} bin/rails db:migrate", exception: true)
    system("#{env} bin/rails annotate:ensure_all_indexes", exception: true)
    system("#{env} bin/annotaterb models #{annotaterb_args}".strip, exception: true)
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
  # One of the indexes on post_search_data is created by a sidekiq job
  # We need to do some acrobatics to create it on-demand
  SeedData::Topics.with_default_locale.create
  SiteSetting.search_enable_recent_regular_posts_offset_size = 1
  Jobs::CreateRecentPostSearchIndexes.new.execute([])
end

desc "regenerate core model annotations using a temporary database"
task "annotate:clean" => :environment do |task, args|
  load_plugins = ENV["LOAD_PLUGINS"].presence || "0"
  model_dir = ENV["MODEL_DIR"].presence || "app/models"
  annotate_in_temp_db(load_plugins: load_plugins, annotaterb_args: "--model-dir #{model_dir}")
  STDERR.puts "Annotate executed successfully"
end

desc "regenerate plugin model annotations using a temporary database"
task "annotate:clean:plugins", [:plugin] => :environment do |task, args|
  specific_plugin = "--model-dir plugins/#{args[:plugin]}/app/models" if args[:plugin].present?
  annotate_in_temp_db(load_plugins: "1", annotaterb_args: specific_plugin.to_s)
  STDERR.puts "Annotate executed successfully"
end
