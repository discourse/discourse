# fix any bust caches post initial migration
ActiveRecord::Base.send(:subclasses).each { |m| m.reset_column_information }
SiteSetting.refresh!
