desc 'Update each post with latest markdown'
task 'posts:rebake' => :environment do
  ENV['RAILS_DB'] ? rebake_posts : rebake_posts_all_sites
end

desc 'Update each post with latest markdown and refresh oneboxes'
task 'posts:refresh_oneboxes' => :environment do
  ENV['RAILS_DB'] ? rebake_posts(invalidate_oneboxes: true) : rebake_posts_all_sites(invalidate_oneboxes: true)
end

def rebake_posts_all_sites(opts = {})
  RailsMultisite::ConnectionManagement.each_connection do |db|
    rebake_posts(opts)
  end
end

def rebake_posts(opts = {})
  puts "Rebaking post markdown for '#{RailsMultisite::ConnectionManagement.current_db}'"

  total = Post.count
  rebaked = 0

  Post.order(updated_at: :asc).find_each do |post|
    rebake_post(post, opts)
    print_status(rebaked += 1, total)
  end

  puts "", "#{rebaked} posts done!", "-" * 50
end

def rebake_post(post, opts)
  post.rebake!(opts)
rescue => e
  puts "", "Failed to rebake (topic_id: #{post.topic_id}, post_id: #{post.id})", e, e.backtrace.join("\n")
end

def print_status(current, max)
  print "\r%9d / %d (%5.1f%%)" % [current, max, ((current.to_f / max.to_f) * 100).round(1)]
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
      p.revise(Discourse.system_user, { raw: normalized })
      putc "."
      i += 1
    end
  end

  puts
  puts "#{i} posts normalized!"
end
