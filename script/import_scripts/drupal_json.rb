# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Edit the constants and initialize method for your import data.

class ImportScripts::DrupalJson < ImportScripts::Base

  JSON_FILES_DIR = "/Users/techapj/Documents"

  def initialize
    super
    @users_json = load_json("formatted_users.json")
  end

  def execute
    puts "", "Importing from Drupal..."

    import_users

    puts "", "Done"
  end

  def load_json(arg)
    filename = File.join(JSON_FILES_DIR, arg)
    raise RuntimeError.new("File #{filename} not found!") if !File.exist?(filename)
    JSON.parse(File.read(filename)).reverse
  end

  def import_users
    puts '', "Importing users"

    create_users(@users_json) do |u|
      {
        id: u["uid"],
        name: u["name"],
        email: u["mail"],
        created_at: Time.zone.at(u["created"].to_i)
      }
    end
    EmailToken.delete_all
  end
end

if __FILE__ == $0
  ImportScripts::DrupalJson.new.perform
end
