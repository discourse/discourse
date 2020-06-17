# frozen_string_literal: true

# fix any bust caches post initial migration
ActiveRecord::Base.connection.tables.each do |table|
  table.classify.constantize.reset_column_information rescue nil
end

SiteSetting.refresh!
