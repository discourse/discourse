desc 'Update each post with latest markdown'
task 'posts:rebake' => :environment do
  rebake_posts
end

desc 'Update each post with latest markdown and refresh oneboxes'
task 'posts:refresh_oneboxes' => :environment do
  rebake_posts invalidate_oneboxes: true
end

def rebake_post(post,opts)
  cooked = post.cook(
    post.raw,
    topic_id: post.topic_id,
    invalidate_oneboxes: opts.fetch(:invalidate_oneboxes, false)
  )

  if cooked != post.cooked
    Post.exec_sql(
      'update posts set cooked = ? where id = ?', cooked, post.id
    )
    post.cooked = cooked
    putc "#"
  else
    putc "."
  end

  TopicLink.extract_from post
  # make sure we trigger the post process
  post.trigger_post_process
rescue => e
  puts "\n\nFailed to bake topic_id #{post.topic_id} post_id #{post.id} #{e}\n#{e.backtrace.join("\n")} \n\n"
end

def rebake_posts(opts = {})
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Re baking post markdown for #{db} , changes are denoted with # , no change with ."

    total = 0
    Post.select([
      :id, :user_id, :cooked, :raw, :topic_id, :post_number
    ]).each do |post|
      rebake_post(post,opts)
      total += 1
    end

    puts "\n\n#{total} posts done!\n#{'-' * 50}\n"
  end
end
