require "csv"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Edit the constants and initialize method for your import data.

class ImportScripts::Muut < ImportScripts::Base

  JSON_FILE_PATH = "/path/to/json/file"
  CSV_FILE_PATH = "/path/to/csv/file"

  def initialize
    super

    @imported_users = load_csv
    @imported_json = load_json
  end

  def execute
    puts "", "Importing from Muut..."

    import_users
    import_categories
    import_discussions

    puts "", "Done"
  end

  def load_json
    JSON.parse(repair_json(File.read(JSON_FILE_PATH)))
  end

  def load_csv
    CSV.parse(File.read(CSV_FILE_PATH))
  end

  def repair_json(arg)
    arg.gsub!(/^\(/, "")     # content of file is surround by ( )
    arg.gsub!(/\)$/, "")

    arg.gsub!(/\]\]$/, "]")  # there can be an extra ] at the end

    arg.gsub!(/\}\{/, "},{") # missing commas sometimes!

    arg.gsub!("}]{", "},{")  # surprise square brackets
    arg.gsub!("}[{", "},{")  # :troll:

    arg
  end

  def import_users
    puts '', "Importing users"

    create_users(@imported_users) do |u|
      {
        id: u[0],
        email: u[1],
        created_at: Time.now
      }
    end
  end


  def import_categories
    puts "", "Importing categories"

    create_categories(@imported_json['categories']) do |category|
      {
        id: category['path'], # muut has no id for categories, so use the path
        name: category['title'],
        slug: category['path']
      }
    end
  end


  def import_discussions
    puts "", "Importing discussions"

    topics = 0
    posts = 0

    @imported_json['categories'].each do |category|


      @imported_json['threads'][category['path']].each do |thread|

        next if thread["seed"]["key"] == "skip-this-topic"

        mapped = {}
        mapped[:id] = "#{thread["seed"]["key"]}-#{thread["seed"]["date"]}"

        if thread["seed"]["author"] && user_id_from_imported_user_id(thread["seed"]["author"]["path"]) != ""
          mapped[:user_id] = user_id_from_imported_user_id(thread["seed"]["author"]["path"]) || -1
        else
          mapped[:user_id] = -1
        end

        # update user display name
        if thread["seed"]["author"] && thread["seed"]["author"]["displayname"] != ""  && mapped[:user_id] != -1
          user = User.find_by(id: mapped[:user_id])
          if user
            user.name = thread["seed"]["author"]["displayname"]
            user.save!
          end
        end

        mapped[:created_at] = Time.zone.at(thread["seed"]["date"])
        mapped[:category] = category_id_from_imported_category_id(thread["seed"]["path"])
        mapped[:title] = CGI.unescapeHTML(thread["seed"]["title"])

        mapped[:raw] = process_muut_post_body(thread["seed"]["body"])
        mapped[:raw] = CGI.unescapeHTML(thread["seed"]["title"]) if mapped[:raw] == ""

        parent_post = create_post(mapped, mapped[:id])
        unless parent_post.is_a?(Post)
          puts "Error creating topic #{mapped[:id]}. Skipping."
          puts parent_post.inspect
        end

        # uncomment below line to create permalink
        # Permalink.create(url: "#{thread["seed"]["path"]}:#{thread["seed"]["key"]}", topic_id: parent_post.topic_id)

        # create replies
        if thread["replies"].present? && thread["replies"].count > 0
          thread["replies"].reverse.each do |post|

            if post_id_from_imported_post_id(post["id"])
              next # already imported this post
            end

            new_post = create_post({
                id: "#{post["key"]}-#{post["date"]}",
                topic_id: parent_post.topic_id,
                user_id: user_id_from_imported_user_id(post["author"]["path"]) || -1,
                raw: process_muut_post_body(post["body"]),
                created_at: Time.zone.at(post["date"])
              }, post["id"])

            if new_post.is_a?(Post)
              posts += 1
            else
              puts "Error creating post #{post["id"]}. Skipping."
              puts new_post.inspect
            end

          end

        end

        topics += 1
      end
    end

    puts "", "Imported #{topics} topics with #{topics + posts} posts."
  end

  def process_muut_post_body(arg)
    raw = arg.dup
    raw = raw.to_s
    raw = raw[2..-3]

    # new line
    raw.gsub!(/\\n/, "\n")

    # code block
    raw.gsub!("---", "```\n")

    # tab
    raw.gsub!(/\\t/, '  ')

    # double quote
    raw.gsub!(/\\\"/, '"')

    raw = CGI.unescapeHTML(raw)
    raw
  end

  def file_full_path(relpath)
    File.join JSON_FILES_DIR, relpath.split("?").first
  end

end

if __FILE__==$0
  ImportScripts::Muut.new.perform
end
