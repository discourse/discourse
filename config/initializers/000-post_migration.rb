unless ['1', 'true'].include?(ENV["SKIP_POST_DEPLOYMENT_MIGRATIONS"]&.to_s)
  Rails.application.config.paths['db/migrate'] << Rails.root.join(
    Discourse::DB_POST_MIGRATE_PATH
  ).to_s
end
