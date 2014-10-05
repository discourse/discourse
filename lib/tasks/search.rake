task "search:reindex" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Reindexing #{db}"
    puts ""
    puts "Posts:"
    Post.exec_sql("select p.id, p.cooked, c.name category, t.title, p.post_number, t.id topic_id from
                   posts p
                   join topics t on t.id = p.topic_id
                   left join categories c on c.id = t.category_id
                   ").each do |p|
      post_id = p["id"]
      cooked = p["cooked"]
      title = p["title"]
      category = p["cat"]
      post_number = p["post_number"].to_i
      topic_id = p["topic_id"].to_i

      SearchObserver.update_posts_index(post_id, cooked, title, category)
      SearchObserver.update_topics_index(topic_id, title , cooked) if post_number == 1

      putc "."
    end

    puts
    puts "Users:"
    User.exec_sql("select id, name, username from users").each do |u|
      id = u["id"]
      name = u["name"]
      username = u["username"]
      SearchObserver.update_users_index(id, username, name)

      putc "."
    end

    puts
    puts "Categories"

    Category.exec_sql("select id, name from categories").each do |c|
      id = c["id"]
      name = c["name"]
      SearchObserver.update_categories_index(id, name)
    end

    puts
  end
end
