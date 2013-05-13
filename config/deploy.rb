set :application, "discourse"
load File.expand_path("~/epic.cap")

after "deploy:symlink_database_yml", "deploy:symlink_redis_yml"
after "deploy:symlink_database_yml", "deploy:symlink_secret_token"

namespace :deploy do
  
  desc "Symlink redis.yml"
  task :symlink_redis_yml, :roles => :app do
    run "ln -nfs #{shared_path}/config/redis.yml #{release_path}/config/redis.yml"
  end
  
  desc "Symlink secret_token.rb"
  task :symlink_secret_token, :roles => :app do
    run "ln -nfs #{shared_path}/config/initializers/secret_token.rb #{release_path}/config/initializers/secret_token.rb"
  end
  
end
