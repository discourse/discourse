desc 'Update each post with latest markdown'
task 'posts:rebake' => :environment do
  ENV['RAILS_DB'] ? rebake_posts : rebake_posts_all_sites
end

desc 'Update each post with latest markdown and refresh oneboxes'
task 'posts:refresh_oneboxes' => :environment do
  ENV['RAILS_DB'] ? rebake_posts(invalidate_oneboxes: true) : rebake_posts_all_sites(invalidate_oneboxes: true)
end

def rebake_post(post,opts)
  changed = post.rebake!(opts)
  if changed
    putc "#"
  else
    putc "."
  end
rescue => e
  puts "\n\nFailed to bake topic_id #{post.topic_id} post_id #{post.id} #{e}\n#{e.backtrace.join("\n")} \n\n"
end

def rebake_posts_all_sites(opts = {})
  RailsMultisite::ConnectionManagement.each_connection do |db|
    rebake_posts(opts)
  end
end

def rebake_posts(opts = {})
  puts "Re baking post markdown for #{RailsMultisite::ConnectionManagement.current_db}, changes are denoted with #, no change with ."

  total = 0
  Post.find_each do |post|
    rebake_post(post,opts)
    total += 1
  end

  puts "\n\n#{total} posts done!\n#{'-' * 50}\n"
end


desc 'normalize all markdown so <pre><code> is not used and instead backticks'
task 'posts:normalize_code' => :environment do
  lang = ENV['CODE_LANG'] || ''
  require 'import/normalize'

  puts "Normalizing"
  i = 0
  Post.where("raw like '%<pre>%<code>%'").each do |p|
    normalized = Import::Normalize.normalize_code_blocks(p.raw, lang)
    if normalized != p.raw
      p.revise(Discourse.system_user, normalized)
      putc "."
      i += 1
    end
  end

  puts
  puts "#{i} posts normalized!"
end
