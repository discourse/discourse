# fix any bust caches post initial migration
ActiveRecord::Base.send(:subclasses).each(&:reset_column_information)
SiteSetting.refresh!
