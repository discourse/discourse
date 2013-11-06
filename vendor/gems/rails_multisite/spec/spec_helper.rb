require 'rubygems'
require 'rails'
require 'active_record'


ENV["RAILS_ENV"] ||= 'test'
RSpec.configure do |config|

  require 'sqlite3'
  class SQLite3::Database
    def self.query_log
      @@query_log ||= []
    end

    alias_method :old_execute, :execute
    alias_method :old_prepare, :prepare

    def execute(*args,&blk)
      self.class.query_log << [args, caller, Thread.current.object_id]
      old_execute(*args,&blk)
    end

    def prepare(*args,&blk)
      self.class.query_log << [args, caller, Thread.current.object_id]
      old_prepare(*args,&blk)
    end

  end

  config.color_enabled = true

  config.before(:suite) do
    ActiveRecord::Base.configurations['test'] = (YAML::load(File.open("spec/fixtures/database.yml"))['test'])
  end

end


