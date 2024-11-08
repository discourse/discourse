# frozen_string_literal: true

desc "ensure the asynchronously-created post_search_data index is present"
task "annotate" => :environment do |task, args|
  system("bin/annotate --models", exception: true)
  STDERR.puts "Annotate executed successfully"

  non_core_plugins =
    Dir["plugins/*"].filter { |plugin_path| `git check-ignore #{plugin_path}`.present? }
  if non_core_plugins.length > 0
    STDERR.puts "Warning: you have non-core plugins installed which may affect the annotations"
    STDERR.puts "For core annotations, consider running `bin/rake annotate:clean`"
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
  db = TemporaryDb.new
  db.start
  db.with_env do
    system("RAILS_ENV=test LOAD_PLUGINS=0 bin/rake db:migrate", exception: true)
    system("RAILS_ENV=test LOAD_PLUGINS=0 bin/rake annotate:ensure_all_indexes", exception: true)
    system(
      "RAILS_ENV=test LOAD_PLUGINS=0 bin/annotate --models --model-dir app/models",
      exception: true,
    )
  end
  STDERR.puts "Annotate executed successfully"
ensure
  db&.stop
  db&.remove
end

desc "regenerate plugin model annotations using a temporary database"
task "annotate:clean:plugins", [:plugin] => :environment do |task, args|
  specific_plugin = "--model-dir plugins/#{args[:plugin]}/app/models" if args[:plugin].present?

  db = TemporaryDb.new
  db.start
  db.with_env do
    system("RAILS_ENV=test LOAD_PLUGINS=1 bin/rake db:migrate", exception: true)
    system("RAILS_ENV=test LOAD_PLUGINS=1 bin/rake annotate:ensure_all_indexes", exception: true)
    system(
      "RAILS_ENV=test LOAD_PLUGINS=1 bin/annotate --models #{specific_plugin}",
      exception: true,
    )
  end
  STDERR.puts "Annotate executed successfully"
ensure
  db&.stop
  db&.remove
end
