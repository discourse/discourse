# frozen_string_literal: true

require 'file_store/local_store'

desc 'Update each post with latest markdown'
task 'posts:rebake' => :environment do
  ENV['RAILS_DB'] ? rebake_posts : rebake_posts_all_sites
end

task 'posts:rebake_uncooked_posts' => :environment do
  # rebaking uncooked posts can very quickly saturate sidekiq
  # this provides an insurance policy so you can safely run and stop
  # this rake task without worrying about your sidekiq imploding
  Jobs.run_immediately!

  ENV['RAILS_DB'] ? rebake_uncooked_posts : rebake_uncooked_posts_all_sites
end

def rebake_uncooked_posts_all_sites
  RailsMultisite::ConnectionManagement.each_connection do |db|
    rebake_uncooked_posts
  end
end

def rebake_uncooked_posts
  puts "Rebaking uncooked posts on #{RailsMultisite::ConnectionManagement.current_db}"
  uncooked = Post.where('baked_version <> ? or baked_version IS NULL', Post::BAKED_VERSION)

  rebaked = 0
  total = uncooked.count

  ids = uncooked.pluck(:id)
  # work randomly so you can run this job from lots of consoles if needed
  ids.shuffle!

  ids.each do |id|
    # may have been cooked in interim
    post = uncooked.where(id: id).first

    if post
      rebake_post(post)
    end

    print_status(rebaked += 1, total)
  end

  puts "", "#{rebaked} posts done!", ""
end

desc 'Update each post with latest markdown and refresh oneboxes'
task 'posts:refresh_oneboxes' => :environment do
  ENV['RAILS_DB'] ? rebake_posts(invalidate_oneboxes: true) : rebake_posts_all_sites(invalidate_oneboxes: true)
end

desc 'Rebake all posts with a quote using a letter_avatar'
task 'posts:fix_letter_avatars' => :environment do
  return unless SiteSetting.external_system_avatars_enabled

  search = Post.where("user_id <> -1")
    .where("raw LIKE '%/letter\_avatar/%' OR cooked LIKE '%/letter\_avatar/%'")

  rebaked = 0
  total = search.count

  search.find_each do |post|
    rebake_post(post)
    print_status(rebaked += 1, total)
  end

  puts "", "#{rebaked} posts done!", ""
end

desc 'Rebake all posts matching string/regex and optionally delay the loop'
task 'posts:rebake_match', [:pattern, :type, :delay] => [:environment] do |_, args|
  args.with_defaults(type: 'string')
  pattern = args[:pattern]
  type = args[:type]&.downcase
  delay = args[:delay]&.to_i

  if !pattern
    puts "ERROR: Expecting rake posts:rebake_match[pattern,type,delay]"
    exit 1
  elsif delay && delay < 1
    puts "ERROR: delay parameter should be an integer and greater than 0"
    exit 1
  elsif type != 'string' && type != 'regex'
    puts "ERROR: Expecting rake posts:rebake_match[pattern,type] where type is string or regex"
    exit 1
  end

  search = Post.raw_match(pattern, type)

  rebaked = 0
  total = search.count

  search.find_each do |post|
    rebake_post(post)
    print_status(rebaked += 1, total)
    sleep(delay) if delay
  end

  puts "", "#{rebaked} posts done!", ""
end

def rebake_posts_all_sites(opts = {})
  RailsMultisite::ConnectionManagement.each_connection do |db|
    rebake_posts(opts)
  end
end

def rebake_posts(opts = {})
  puts "Rebaking post markdown for '#{RailsMultisite::ConnectionManagement.current_db}'"

  begin
    disable_system_edit_notifications = SiteSetting.disable_system_edit_notifications
    SiteSetting.disable_system_edit_notifications = true

    total = Post.count
    rebaked = 0
    batch = 1000
    Post.update_all('baked_version = NULL')

    (0..(total - 1).abs).step(batch) do |i|
      Post.order(id: :desc).offset(i).limit(batch).each do |post|
        rebake_post(post, opts)
        print_status(rebaked += 1, total)
      end
    end
  ensure
    SiteSetting.disable_system_edit_notifications = disable_system_edit_notifications
  end

  puts "", "#{rebaked} posts done!", "-" * 50
end

def rebake_post(post, opts = {})
  if !opts[:priority]
    opts[:priority] = :ultra_low
  end
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
      p.revise(Discourse.system_user, raw: normalized)
      putc "."
      i += 1
    end
  end

  puts
  puts "#{i} posts normalized!"
end

def remap_posts(find, type, ignore_case, replace = "")
  ignore_case = ignore_case == 'true'
  i = 0

  Post.raw_match(find, type).find_each do |p|
    regex =
      case type
      when 'string' then
        Regexp.new(Regexp.escape(find), ignore_case)
      when 'regex' then
        Regexp.new(find, ignore_case)
      end

    new_raw = p.raw.gsub(regex, replace)

    if new_raw != p.raw
      begin
        p.revise(Discourse.system_user, { raw: new_raw }, bypass_bump: true, skip_revision: true)
        putc "."
        i += 1
      rescue
        puts "\nFailed to remap post (topic_id: #{p.topic_id}, post_id: #{p.id})\n"
      end
    end
  end

  i
end

desc 'Remap all posts matching specific string'
task 'posts:remap', [:find, :replace, :type, :ignore_case] => [:environment] do |_, args|
  require 'highline/import'

  args.with_defaults(type: 'string', ignore_case: 'false')
  find = args[:find]
  replace = args[:replace]
  type = args[:type]&.downcase
  ignore_case = args[:ignore_case]&.downcase

  if !find
    puts "ERROR: Expecting rake posts:remap['find','replace']"
    exit 1
  elsif !replace
    puts "ERROR: Expecting rake posts:remap['find','replace']. Want to delete a word/string instead? Try rake posts:delete_word['word-to-delete']"
    exit 1
  elsif type != 'string' && type != 'regex'
    puts "ERROR: Expecting rake posts:remap['find','replace',type] where type is string or regex"
    exit 1
  elsif ignore_case != 'true' && ignore_case != 'false'
    puts "ERROR: Expecting rake posts:remap['find','replace',type,ignore_case] where ignore_case is true or false"
    exit 1
  else
    confirm_replace = ask("Are you sure you want to replace all #{type} occurrences of '#{find}' with '#{replace}'? (Y/n)")
    exit 1 unless (confirm_replace == "" || confirm_replace.downcase == 'y')
  end

  puts "Remapping"
  total = remap_posts(find, type, ignore_case, replace)
  puts "", "#{total} posts remapped!", ""
end

desc 'Delete occurrence of a word/string'
task 'posts:delete_word', [:find, :type, :ignore_case] => [:environment] do |_, args|
  require 'highline/import'

  args.with_defaults(type: 'string', ignore_case: 'false')
  find = args[:find]
  type = args[:type]&.downcase
  ignore_case = args[:ignore_case]&.downcase

  if !find
    puts "ERROR: Expecting rake posts:delete_word['word-to-delete']"
    exit 1
  elsif type != 'string' && type != 'regex'
    puts "ERROR: Expecting rake posts:delete_word[pattern, type] where type is string or regex"
    exit 1
  elsif ignore_case != 'true' && ignore_case != 'false'
    puts "ERROR: Expecting rake posts:delete_word[pattern, type,ignore_case] where ignore_case is true or false"
    exit 1
  else
    confirm_delete = ask("Are you sure you want to remove all #{type} occurrences of '#{find}'? (Y/n)")
    exit 1 unless (confirm_delete == "" || confirm_delete.downcase == 'y')
  end

  puts "Processing"
  total = remap_posts(find, type, ignore_case)
  puts "", "#{total} posts updated!", ""
end

desc 'Delete all likes'
task 'posts:delete_all_likes' => :environment do

  post_actions = PostAction.where(post_action_type_id: PostActionType.types[:like])

  likes_deleted = 0
  total = post_actions.count

  post_actions.each do |post_action|
    begin
      post_action.remove_act!(Discourse.system_user)
      print_status(likes_deleted += 1, total)
    rescue
      # skip
    end
  end

  UserStat.update_all(likes_given: 0, likes_received: 0) # clear user likes stats
  DirectoryItem.update_all(likes_given: 0, likes_received: 0) # clear user directory likes stats
  puts "", "#{likes_deleted} likes deleted!", ""
end

desc 'Refreshes each post that was received via email'
task 'posts:refresh_emails', [:topic_id] => [:environment] do |_, args|
  posts = Post.where.not(raw_email: nil).where(via_email: true)
  posts = posts.where(topic_id: args[:topic_id]) if args[:topic_id]

  updated = 0
  total = posts.count

  posts.find_each do |post|
    begin
      receiver = Email::Receiver.new(post.raw_email)

      body, elided = receiver.select_body
      body = receiver.add_attachments(body || '', post.user)
      body << Email::Receiver.elided_html(elided) if elided.present?

      post.revise(Discourse.system_user, { raw: body, cook_method: Post.cook_methods[:regular] },
                  skip_revision: true, skip_validations: true, bypass_bump: true)
    rescue
      puts "Failed to refresh post (topic_id: #{post.topic_id}, post_id: #{post.id})"
    end

    updated += 1

    print_status(updated, total)
  end

  puts "", "Done. #{updated} posts updated.", ""
end

desc 'Reorders all posts based on their creation_date'
task 'posts:reorder_posts', [:topic_id] => [:environment] do |_, args|
  Post.transaction do
    # update sort_order and flip post_number to prevent
    # unique constraint violations when updating post_number
    builder = DB.build(<<~SQL)
      WITH ordered_posts AS (
          SELECT
            id,
            ROW_NUMBER()
            OVER (
              PARTITION BY topic_id
              ORDER BY created_at, post_number ) AS new_post_number
          FROM posts
          /*where*/
      )
      UPDATE posts AS p
      SET sort_order = o.new_post_number,
        post_number  = p.post_number * -1
      FROM ordered_posts AS o
      WHERE p.id = o.id AND
            p.post_number <> o.new_post_number
    SQL
    builder.where("topic_id = :topic_id") if args[:topic_id]
    builder.exec(topic_id: args[:topic_id])

    DB.exec(<<~SQL)
      UPDATE notifications AS x
      SET post_number = p.sort_order
      FROM posts AS p
      WHERE x.topic_id = p.topic_id AND
            x.post_number = ABS(p.post_number) AND
            p.post_number < 0
    SQL

    DB.exec(<<~SQL)
      UPDATE post_timings AS x
      SET post_number = x.post_number * -1
      FROM posts AS p
      WHERE x.topic_id = p.topic_id AND
            x.post_number = ABS(p.post_number) AND
            p.post_number < 0;

      UPDATE post_timings AS t
      SET post_number = p.sort_order
      FROM posts AS p
      WHERE t.topic_id = p.topic_id AND
            t.post_number = p.post_number AND
            p.post_number < 0;
    SQL

    DB.exec(<<~SQL)
      UPDATE posts AS x
      SET reply_to_post_number = p.sort_order
      FROM posts AS p
      WHERE x.topic_id = p.topic_id AND
            x.reply_to_post_number = ABS(p.post_number) AND
            p.post_number < 0;
    SQL

    DB.exec(<<~SQL)
      UPDATE topic_users AS x
        SET last_read_post_number = p.sort_order
      FROM posts AS p
      WHERE x.topic_id = p.topic_id AND
            x.last_read_post_number = ABS(p.post_number) AND
            p.post_number < 0;

      UPDATE topic_users AS x
        SET highest_seen_post_number = p.sort_order
      FROM posts AS p
      WHERE x.topic_id = p.topic_id AND
            x.highest_seen_post_number = ABS(p.post_number) AND
            p.post_number < 0;

      UPDATE topic_users AS x
        SET last_emailed_post_number = p.sort_order
      FROM posts AS p
      WHERE x.topic_id = p.topic_id AND
            x.last_emailed_post_number = ABS(p.post_number) AND
            p.post_number < 0;
    SQL

    # finally update the post_number
    DB.exec(<<~SQL)
      UPDATE posts
      SET post_number = sort_order
      WHERE post_number < 0
    SQL
  end

  puts "", "Done.", ""
end

def missing_uploads
  puts "Looking for missing uploads on: #{RailsMultisite::ConnectionManagement.current_db}"

  old_scheme_upload_count = 0

  count_missing = 0

  missing = Post.find_missing_uploads(include_local_upload: true) do |post, src, path, sha1|
    next if sha1.present?
    puts "Fixing missing uploads: " if count_missing == 0
    count_missing += 1

    upload_id = nil

    # recovering old scheme upload.
    local_store = FileStore::LocalStore.new
    public_path = "#{local_store.public_dir}#{path}"
    file_path = nil

    if File.file?(public_path)
      file_path = public_path
    else
      tombstone_path = public_path.sub("/uploads/", "/uploads/tombstone/")
      file_path = tombstone_path if File.file?(tombstone_path)
    end

    if file_path.present?
      if (upload = UploadCreator.new(File.open(file_path), File.basename(path)).create_for(Discourse.system_user.id)).persisted?
        upload_id = upload.id

        post.reload
        new_raw = post.raw.dup
        new_raw = new_raw.gsub(path, upload.url)

        PostRevisor.new(post, Topic.with_deleted.find_by(id: post.topic_id)).revise!(
          Discourse.system_user,
          {
            raw: new_raw
          },
          skip_validations: true,
          force_new_version: true,
          bypass_bump: true
        )

        print "🆗"
      else
        print "❌"
      end
    else
      print "🚫"
      old_scheme_upload_count += 1
    end

    upload_id
  end

  puts "", "#{missing[:count]} post uploads are missing.", ""

  if missing[:count] > 0
    puts "#{missing[:uploads].count} uploads are missing."
    puts "#{old_scheme_upload_count} of #{missing[:uploads].count} are old scheme uploads." if old_scheme_upload_count > 0
    puts "#{missing[:post_uploads].count} of #{Post.count} posts are affected.", ""

    if ENV['GIVE_UP'] == "1"
      missing[:post_uploads].each do |id, uploads|
        post = Post.with_deleted.find_by(id: id)
        if post
          puts "#{post.full_url} giving up on #{uploads.length} upload(s)"
          PostCustomField.create!(post_id: post.id, name: Post::MISSING_UPLOADS_IGNORED, value: "t")
        else
          puts "could not find post #{id}"
        end
      end
    end

    if ENV['VERBOSE'] == "1"
      puts "missing uploads!"
      missing[:uploads].each do |path|
        puts "#{path}"
      end

      if missing[:post_uploads].count > 0
        puts
        puts "Posts with missing uploads"
        missing[:post_uploads].each do |id, uploads|
          post = Post.with_deleted.find_by(id: id)
          if post
            puts "#{post.full_url} missing #{uploads.join(", ")}"
          else
            puts "could not find post #{id}"
          end
        end
      end
    end
  end

  missing[:count] == 0
end

desc 'Finds missing post upload records from cooked HTML content'
task 'posts:missing_uploads' => :environment do |_, args|
  if ENV["RAILS_DB"]
    missing_uploads
  else
    RailsMultisite::ConnectionManagement.each_connection do
      missing_uploads
    end
  end
end

def recover_uploads_from_index(path)
  lookup = []

  db = RailsMultisite::ConnectionManagement.current_db
  cdn_path = SiteSetting.cdn_path("/uploads/#{db}").sub(/https?:/, "")
  Post.where("cooked LIKE '%#{cdn_path}%'").each do |post|
    regex = Regexp.new("((https?:)?#{Regexp.escape(cdn_path)}[^,;\\]\\>\\t\\n\\s)\"\']+)")
    uploads = []
    post.raw.scan(regex).each do |match|
      uploads << match[0]
    end

    if uploads.length > 0
      lookup << [post.id, uploads]
    else
      print "."
      post.rebake!
    end
  end

  PostCustomField.where(name: Post::MISSING_UPLOADS).pluck(:post_id, :value).each do |post_id, uploads|
    uploads = JSON.parse(uploads)
    raw = Post.where(id: post_id).pluck_first(:raw)
    uploads.map! do |upload|
      orig = upload
      if raw.scan(upload).length == 0
        upload = upload.sub(SiteSetting.Upload.s3_cdn_url, SiteSetting.Upload.s3_base_url)
      end
      if raw.scan(upload).length == 0
        upload = upload.sub(SiteSetting.Upload.s3_base_url, Discourse.base_url)
      end
      if raw.scan(upload).length == 0
        upload = upload.sub(Discourse.base_url + "/", "/")
      end
      if raw.scan(upload).length == 0
        # last resort, try for sha
        sha = upload.split("/")[-1]
        sha = sha.split(".")[0]

        if sha.length == 40 && raw.scan(sha).length == 1
          raw.match(Regexp.new("([^\"'<\\s\\n]+#{sha}[^\"'>\\s\\n]+)"))
          upload = $1
        end
      end
      if raw.scan(upload).length == 0
        puts "can not find #{orig} in\n\n#{raw}"
        upload = nil
      end
      upload
    end
    uploads.compact!
    if uploads.length > 0
      lookup << [post_id, uploads]
    end
  end

  lookup.each do |post_id, uploads|
    post = Post.find(post_id)
    changed = false

    uploads.each do |url|
      if (n = post.raw.scan(url).length) != 1
        puts "Skipping #{url} in #{post.full_url} cause it appears #{n} times"
        next
      end

      name = File.basename(url).split("_")[0].split(".")[0]
      puts "Searching for #{url} (#{name}) in index"
      if name.length != 40
        puts "Skipping #{url} in #{post.full_url} cause it appears to have a short file name"
        next
      end
      found = `cat #{path} | grep #{name} | grep original`.split("\n")[0] rescue nil
      if found.blank?
        puts "Skipping #{url} in #{post.full_url} cause it missing from index"
        next
      end

      found = File.expand_path(File.join(File.dirname(path), found))
      if !File.exist?(found)
        puts "Skipping #{url} in #{post.full_url} cause it missing from disk"
        next
      end

      File.open(found) do |f|
        begin
          upload = UploadCreator.new(f, "upload").create_for(post.user_id)
          if upload && upload.url
            post.raw = post.raw.sub(url, upload.url)
            changed = true
          else
            puts "Skipping #{url} in #{post.full_url} unable to create upload (unknown error)"
            next
          end
        rescue Discourse::InvalidAccess
          puts "Skipping #{url} in #{post.full_url} unable to create upload (bad format)"
          next
        end
      end
    end
    if changed
      puts "Recovered uploads on #{post.full_url}"
      post.save!(validate: false)
      post.rebake!
    end
  end
end

desc 'Attempts to recover missing uploads from an index file'
task 'posts:recover_uploads_from_index' => :environment do |_, args|
  path = File.expand_path(Rails.root + "public/uploads/all_the_files")
  if File.exist?(path)
    puts "Found existing index file at #{path}"
  else
    puts "Can not find index #{path} generating index this could take a while..."
    `cd #{File.dirname(path)} && find -type f > #{path}`
  end
  if RailsMultisite::ConnectionManagement.current_db != "default"
    recover_uploads_from_index(path)
  else
    RailsMultisite::ConnectionManagement.each_connection do
      recover_uploads_from_index(path)
    end
  end
end

desc 'invalidate broken images'
task 'posts:invalidate_broken_images' => :environment do
  puts "Invalidating broken images.."

  posts = Post.where("raw like '%<img%'")

  rebaked = 0
  total = posts.count

  posts.find_each do |p|
    rebake_post(p, invalidate_broken_images: true)
    print_status(rebaked += 1, total)
  end

  puts
  puts "", "#{rebaked} posts rebaked!"
end

desc "Coverts full upload URLs in `Post#raw` to short upload url"
task 'posts:inline_uploads' => :environment do |_, args|
  if ENV['RAILS_DB']
    correct_inline_uploads
  else
    RailsMultisite::ConnectionManagement.each_connection do |db|
      puts "Correcting #{db}..."
      puts
      correct_inline_uploads
    end
  end
end

def correct_inline_uploads
  dry_run = (ENV["DRY_RUN"].nil? ? true : ENV["DRY_RUN"] != "false")
  verbose = ENV["VERBOSE"]

  scope = Post.joins(:post_uploads).distinct("posts.id")
    .where(<<~SQL)
    raw LIKE '%/uploads/#{RailsMultisite::ConnectionManagement.current_db}/original/%'
    SQL

  affected_posts_count = scope.count
  fixed_count = 0
  not_corrected_post_ids = []
  failed_to_correct_post_ids = []

  scope.find_each do |post|
    if post.raw !~ Upload::URL_REGEX
      affected_posts_count -= 1
      next
    end

    begin
      new_raw = InlineUploads.process(post.raw)

      if post.raw != new_raw
        if !dry_run
          PostRevisor.new(post, Topic.with_deleted.find_by(id: post.topic_id))
            .revise!(
              Discourse.system_user,
              {
                raw: new_raw
              },
              skip_validations: true,
              force_new_version: true,
              bypass_bump: true
            )
        end

        if verbose
          require 'diffy'
          Diffy::Diff.default_format = :color
          puts "Cooked diff for Post #{post.id}"
          puts Diffy::Diff.new(PrettyText.cook(post.raw), PrettyText.cook(new_raw), context: 1)
          puts
        elsif dry_run
          putc "#"
        else
          putc "."
        end

        fixed_count += 1
      else
        putc "X"
        not_corrected_post_ids << post.id
      end
    rescue
      putc "!"
      failed_to_correct_post_ids << post.id
    end
  end

  puts
  puts "#{fixed_count} out of #{affected_posts_count} affected posts corrected"

  if not_corrected_post_ids.present?
    puts "Ids of posts that were not corrected: #{not_corrected_post_ids}"
  end

  if failed_to_correct_post_ids.present?
    puts "Ids of posts that encountered failures: #{failed_to_correct_post_ids}"
  end

  if dry_run
    puts "Task was ran in dry run mode. Set `DRY_RUN=false` to revise affected posts"
  end
end
