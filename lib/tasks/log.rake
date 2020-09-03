task :log => :environment do
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end
