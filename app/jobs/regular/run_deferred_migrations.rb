module Jobs
  class RunDeferredMigrations < Jobs::Base
    def execute(_)
      if Rails.env.production?
        ActiveRecord::Migrator.migrate('db/deferred_migrate', nil)
      end
    end
  end
end
