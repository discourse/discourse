task "search:reindex" => :environment do
  ENV['RAILS_DB'] ? reindex_search : reindex_search_all_sites
end

def reindex_search(db = RailsMultisite::ConnectionManagement.current_db)
  puts "Reindexing '#{db}'"
  puts ""
  puts "Posts"
  Post.includes(topic: [:category, :tags]).find_each do |p|
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
  RailsMultisite::ConnectionManagement.each_connection do |db|
    reindex_search(db)
  end
end
