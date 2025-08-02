# frozen_string_literal: true

task log: :environment do
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end
