# frozen_string_literal: true

require "csv"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Import script for forums created via mybb.ru service (or anything else that uses this simple JSON format),
# using export format produced by https://github.com/AlexP11223/MybbRuUserscripts
# Set ENV variables, e.g. "export JSON_TOPICS_FILE=my_path/threads.json", or set/use the paths in the constants below
# If your forum has non-English usernames, don't forget to enable Unicode usernames in /admin/site_settings

class ImportScripts::MybbRu < ImportScripts::Base

  JSON_TOPICS_FILE_PATH ||= ENV['JSON_TOPICS_FILE'] || 'mybbru_export/threads.json'
  JSON_USERS_FILE_PATH ||= ENV['JSON_USERS_FILE'] || 'mybbru_export/users.json'

  def initialize
    super

    @imported_topics = load_json(JSON_TOPICS_FILE_PATH)
    @imported_users = load_json(JSON_USERS_FILE_PATH)
  end

  def execute
    puts "", "Importing from JSON file..."

    import_users
    import_categories
    import_discussions

    puts "", "Done"
  end

  def load_json(path)
    JSON.parse(File.read(path))
  end

  def clean_username(name)
    name.gsub(/ /, '')
  end

  def import_users
    puts '', "Importing users"

    create_users(@imported_users) do |u|
      {
        id: u['id'],
        username: clean_username(u['name']),
        email: u['email'],
        created_at: Time.now
      }
    end
  end

  def import_categories
    puts "", "importing categories..."

    categories = @imported_topics.map { |t| t['category'] }.uniq

    create_categories(categories) do |c|
      {
        id: c['id'],
        name: c['name']
      }
    end
  end

  def import_discussions
    puts "", "Importing discussions"

    @imported_topics.each do |t|
      first_post = t['posts'][0]

      create_posts(t['posts']) do |p|
        result = {
          id: p['id'],
          user_id: user_id_from_imported_user_id(p['author']['id']),
          raw: fix_post_content(p["source"]),
          created_at: Time.at(p['createdAt']),
          cook_method: Post.cook_methods[:regular]
        }

        if p['id'] == first_post['id']
          result[:category] = category_id_from_imported_category_id(t['category']['id'])
          result[:title] = t['title']
        else
          parent = topic_lookup_from_imported_post_id(first_post['id'])
          if parent
            result[:topic_id] = parent[:topic_id]
          else
            puts "Parent post #{first_post['id']} doesn't exist. Skipping #{p["id"]}: #{t["title"][0..40]}"
            break
          end
        end

        result
      end
    end
  end

  def fix_post_content(text)
    text
      .gsub(/\[code\]/, "\n[code]\n")
      .gsub(/\[\/code\]/, "\n[/code]\n")
      .gsub(/\[video\]/, "")
      .gsub(/\[\/video\]/, "")
      .gsub(/\[quote.*?\]/, "\n" + '\0' + "\n")
      .gsub(/\[\/quote\]/, "\n[/quote]\n")
      .gsub(/\[spoiler.*?\]/, "\n" + '\0' + "\n").gsub(/\[spoiler/, '[details')
      .gsub(/\[\/spoiler\]/, "\n[/details]\n")
  end
end

if __FILE__ == $0
  ImportScripts::MybbRu.new.perform
end
