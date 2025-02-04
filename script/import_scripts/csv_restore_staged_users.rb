# frozen_string_literal: true

require "csv"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Edit the constants and initialize method for your import data.

class ImportScripts::CsvRestoreStagedUsers < ImportScripts::Base
  CSV_FILE_PATH = ENV["CSV_USER_FILE"]
  CSV_CUSTOM_FIELDS = ENV["CSV_CUSTOM_FIELDS"]
  CSV_EMAILS = ENV["CSV_EMAILS"]

  BATCH_SIZE = 1000

  def initialize
    super

    @imported_users = load_csv(CSV_FILE_PATH)
    @imported_emails = load_csv(CSV_EMAILS)
    @imported_custom_fields = load_csv(CSV_CUSTOM_FIELDS)
    @skip_updates = true
  end

  def execute
    puts "", "Importing from CSV file..."

    import_users

    puts "", "Done"
  end

  def load_csv(path)
    CSV.parse(File.read(path), headers: true)
  end

  def username_for(name)
    result = name.downcase.gsub(/[^a-z0-9\-\_]/, "")

    result = Digest::SHA1.hexdigest(name)[0...10] if result.blank?

    result
  end

  def get_email(id)
    email = nil
    @imported_emails.each { |e| email = e["email"] if e["user_id"] == id }
    email
  end

  def get_custom_fields(id)
    custom_fields = {}
    @imported_custom_fields.each do |cf|
      custom_fields[cf["name"]] = cf["value"] if cf["user_id"] == id
    end
    custom_fields
  end

  def import_users
    puts "", "Importing users"

    users = []
    @imported_users.each do |u|
      email = get_email(u["id"])
      custom_fields = get_custom_fields(u["id"])
      u["email"] = email
      u["custom_fields"] = custom_fields
      users << u
    end
    users.uniq!

    create_users(users) do |u|
      {
        id: u["id"],
        username: u["username"],
        email: u["email"],
        created_at: u["created_at"],
        staged: u["staged"],
        custom_fields: u["custom_fields"],
      }
    end
  end
end

ImportScripts::CsvRestoreStagedUsers.new.perform if __FILE__ == $0
