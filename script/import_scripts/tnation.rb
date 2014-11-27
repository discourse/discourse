# custom importer for www.t-nation.com, feel free to borrow ideas

require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require "mysql2"

class ImportScripts::Tnation < ImportScripts::Base

  DATABASE = "tnation"

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      database: DATABASE
    )
  end

  def execute
  end

end

ImportScripts::Tnation.new.perform
