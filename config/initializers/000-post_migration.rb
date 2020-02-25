# frozen_string_literal: true

unless Discourse.skip_post_deployment_migrations?
  ActiveRecord::Tasks::DatabaseTasks.migrations_paths << Rails.root.join(
    Discourse::DB_POST_MIGRATE_PATH
  ).to_s
end
