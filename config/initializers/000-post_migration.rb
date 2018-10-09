unless Discourse.skip_post_deployment_migrations?
  Rails.application.config.paths['db/migrate'] << Rails.root.join(
    Discourse::DB_POST_MIGRATE_PATH
  ).to_s
end
