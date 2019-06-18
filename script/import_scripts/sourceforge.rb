# frozen_string_literal: true

require_relative 'base.rb'

# Import script for SourceForge discussions.
#
# See the following instructions on how to export your discussions from SourceForge:
# https://sourceforge.net/p/forge/documentation/Project%20Data%20Export/
#
# Change the constants (PROJECT_NAME and JSON_FILE) before running the importer!
#
# Use the following command to run the importer within the Docker container:
# su discourse -c 'ruby /var/www/discourse/script/import_scripts/sourceforge.rb'

class ImportScripts::Sourceforge < ImportScripts::Base
  # When the URL of your project is https://sourceforge.net/projects/foo/
  # than the value of PROJECT_NAME is 'foo'
  PROJECT_NAME = 'project_name'

  # This is the path to the discussion.json that you exported from SourceForge.
  JSON_FILE = '/path/to/discussion.json'

  def initialize
    super

    @system_user = Discourse.system_user
  end

  def execute
    puts '', 'Importing from SourceForge...'

    load_json

    import_categories
    import_topics
  end

  def load_json
    @json = MultiJson.load(File.read(JSON_FILE), symbolize_keys: true)
  end

  def import_categories
    puts '', 'importing categories'

    create_categories(@json[:forums]) do |forum|
      {
        id: forum[:shortname],
        name: forum[:name],
        post_create_action: proc do |category|
          changes = { raw: forum[:description] }
          opts = { revised_at: Time.now, bypass_bump: true }

          post = category.topic.first_post
          post.revise(@system_user, changes, opts)
        end
      }
    end
  end

  def import_topics
    puts '', 'importing posts'
    imported_post_count = 0
    total_post_count = count_posts

    @json[:forums].each do |forum|
      imported_category_id = @lookup.category_id_from_imported_category_id(forum[:shortname])

      forum[:threads].each do |thread|
        posts = thread[:posts]
        next if posts.size == 0

        first_post = posts[0]
        first_post_id = post_id_of(thread, first_post)
        imported_topic = nil

        create_posts(posts, total: total_post_count, offset: imported_post_count) do |post|
          mapped = {
            id: "#{thread[:_id]}_#{post[:slug]}",
            user_id: @system_user,
            created_at: Time.zone.parse(post[:timestamp]),
            raw: process_post_text(forum, thread, post)
          }

          if post == first_post
            mapped[:category] = imported_category_id
            mapped[:title] = thread[:subject][0...255]
          else
            if imported_topic.nil?
              imported_topic = @lookup.topic_lookup_from_imported_post_id(first_post_id)
            end

            mapped[:topic_id] = imported_topic[:topic_id]
          end

          imported_post_count += 1
          mapped
        end
      end
    end
  end

  def count_posts
    total_count = 0

    @json[:forums].each do |forum|
      forum[:threads].each do |thread|
        total_count += thread[:posts].size
      end
    end

    total_count
  end

  def post_id_of(thread, post)
    "#{thread[:_id]}_#{post[:slug]}"
  end

  def process_post_text(forum, thread, post)
    text = post[:text]
    text.gsub!(/~{3,}/, '```') # Discourse doesn't recognize ~~~ as beginning/end of code blocks

    # SourceForge doesn't allow symbols in usernames, so we are safe here.
    # Well, unless it's the anonymous user, which has an evil asterisk in the JSON file...
    username = post[:author]
    username = 'anonymous' if username == '*anonymous'

    # anonymous and nobody are nonexistent users. Make sure we don't create links for them.
    user_without_profile = username == 'anonymous' || username == 'nobody'
    user_link = user_without_profile ? username : "[#{username}](https://sourceforge.net/u/#{username}/)"

    # Create a nice looking header for each imported post that links to the author's user profile and the old post.
    post_date = Time.zone.parse(post[:timestamp]).strftime('%A, %B %d, %Y')
    post_url = "https://sourceforge.net/p/#{PROJECT_NAME}/discussion/#{forum[:shortname]}/thread/#{thread[:_id]}/##{post[:slug]}"

    "**#{user_link}** wrote on [#{post_date}](#{post_url}):\n\n#{text}"
  end
end

ImportScripts::Sourceforge.new.perform
