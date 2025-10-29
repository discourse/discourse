# frozen_string_literal: true

task "search:reindex" => :environment do
  ENV["RAILS_DB"] ? reindex_search : reindex_search_all_sites
end

task "search:reindex_localizations" => :environment do
  ENV["RAILS_DB"] ? reindex_localizations : reindex_localizations_all_sites
end

def reindex_search(db = RailsMultisite::ConnectionManagement.current_db)
  puts "Reindexing '#{db}'"
  puts ""
  puts "Posts"
  Post
    .includes(topic: %i[category tags])
    .find_each do |p|
      if p.post_number == 1
        SearchIndexer.index(p.topic, force: true)
      else
        SearchIndexer.index(p, force: true)
      end
      putc "."
    end

  puts
  puts "Users"
  User.find_each do |u|
    SearchIndexer.index(u, force: true)
    putc "."
  end

  puts
  puts "Categories"

  Category.find_each do |c|
    SearchIndexer.index(c, force: true)
    putc "."
  end

  puts
  puts "Tags"

  Tag.find_each do |t|
    SearchIndexer.index(t, force: true)
    putc "."
  end

  puts
end

def reindex_search_all_sites
  RailsMultisite::ConnectionManagement.each_connection { |db| reindex_search(db) }
end

def reindex_localizations(db = RailsMultisite::ConnectionManagement.current_db)
  return unless SiteSetting.content_localization_enabled

  puts "Reindexing localizations for '#{db}'"
  puts ""

  errors = []

  puts "Topic Localizations"
  # Preload all necessary associations to avoid N+1 queries
  Topic
    .joins(:topic_localizations)
    .includes(:posts, :category, :tags, :topic_localizations)
    .distinct
    .find_each do |topic|
      begin
        SearchIndexer.index_topic_localizations(topic)
        putc "."
      rescue StandardError => e
        errors << "Topic #{topic.id}: #{e.message}"
      end
    end

  puts
  puts "Post Localizations"
  # Preload all necessary associations to avoid N+1 queries
  Post
    .joins(:post_localizations)
    .includes(:post_localizations, topic: %i[category tags topic_localizations])
    .distinct
    .find_each do |post|
      begin
        SearchIndexer.index_post_localizations(post)
        putc "."
      rescue StandardError => e
        errors << "Post #{post.id}: #{e.message}"
      end
    end

  puts
  puts "Localization reindexing complete!"

  if errors.any?
    puts "#{errors.count} errors occurred:"
    errors.each { |error| puts "  - #{error}" }
  end
end

def reindex_localizations_all_sites
  RailsMultisite::ConnectionManagement.each_connection { |db| reindex_localizations(db) }
end
