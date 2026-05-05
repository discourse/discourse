# frozen_string_literal: true

# fix_vb5_comments.rb
#
# Reorders posts in Discourse topics that have out-of-order post numbers due to
# vBulletin comments being imported after the initial migration.
#
# When this set of vb5 scripts was first created, it didn't handle comments. So when we added a
# handler and imported them, they showed up at the end of each topic with high post_numbers, even
# though their created_at timestamps may be much earlier. This script detects those topics and
# reorders all posts chronologically.
#
# Usage:
#   bundle exec rails runner script/import_scripts/vbulletin5/fix_vb5_comments.rb
#
# Options:
#   TOPIC_ID=N - process only the single Discourse topic with this ID (for testing)
#   DRY_RUN=1  - simulate reordering without writing to the database
#   VERBOSE=1  - print per-post renumbering details for each topic
#
# Safe to re-run: topics already in correct chronological order are skipped.
# Resumable: Writes a file /tmp/vb_fix_comments_checkpoint to track progress.
# In DRY_RUN mode, no checkpoint is written or deleted.
# TOPIC_ID mode bypasses the checkpoint entirely.
#
# What it updates per topic (all in a single transaction):
#   - posts.post_number and posts.sort_order (reassigned 1..N by created_at ASC, id ASC)
#   - posts.reply_to_post_number (remapped using old→new post_number map)
#   - topics.highest_post_number
#   - topic_users.last_read_post_number (capped at new highest)

DRY_RUN  = ENV["DRY_RUN"].present?
VERBOSE  = ENV["VERBOSE"].present?
TOPIC_ID = ENV["TOPIC_ID"].presence&.to_i
CHECKPOINT_FILE = "/tmp/vb_fix_comments_checkpoint"

puts "DRY RUN MODE - no database writes will be performed" if DRY_RUN

affected_topic_ids =
  if TOPIC_ID
    puts "Only processing #{TOPIC_ID}#{DRY_RUN ? " (dry run)" : ""}..."
    [TOPIC_ID]
  else
    last_topic_id =
      if !DRY_RUN && File.exist?(CHECKPOINT_FILE)
        val = File.read(CHECKPOINT_FILE).strip.to_i
        puts "Resuming from topic_id > #{val}"
        val
      else
        0
      end

    DB.query_single(<<~SQL)
      SELECT DISTINCT p1.topic_id
      FROM posts p1
      JOIN posts p2
        ON p2.topic_id = p1.topic_id
       AND p2.post_number = p1.post_number + 1
      WHERE p1.topic_id > #{last_topic_id}
        AND p1.post_number >= 1
        AND p1.created_at > p2.created_at
        AND p1.deleted_at IS NULL
        AND p2.deleted_at IS NULL
      ORDER BY p1.topic_id
    SQL
  end

total = affected_topic_ids.size

if total == 0
  puts "Nothing to do."
  File.delete(CHECKPOINT_FILE) if File.exist?(CHECKPOINT_FILE)
  exit 0
else
  puts "#{total} topic(s) need reordering"
end

reordered = 0
skipped   = 0
errors    = 0

# Load all non-deleted posts ordered by created_at ASC, id ASC (id breaks ties
# for posts with identical timestamps).
affected_topic_ids.each_with_index do |topic_id, idx|
  begin
    posts =
      DB.query(<<~SQL)
        SELECT id, post_number, created_at, reply_to_post_number
        FROM posts
        WHERE topic_id = #{topic_id}
          AND deleted_at IS NULL
        ORDER BY created_at ASC, id ASC
      SQL

    if posts.empty?
      puts "  [topic #{topic_id}] SKIP: no posts found"
      skipped += 1
      File.write(CHECKPOINT_FILE, topic_id.to_s) unless DRY_RUN
      next
    end

    # Build old_post_number → new_post_number mapping.
    old_to_new = {}
    posts.each_with_index { |p, i| old_to_new[p.post_number] = i + 1 }

    # Skip if already in correct order.
    if old_to_new.all? { |old, new_num| old == new_num }
      puts "  [topic #{topic_id}] already in order, skipping" if VERBOSE
      skipped += 1
      File.write(CHECKPOINT_FILE, topic_id.to_s) unless DRY_RUN
      next
    end

    new_highest = posts.size

    puts "  [topic #{topic_id}] #{DRY_RUN ? "DRY RUN: Would reorder" : "Reordering"} #{posts.size} posts..."
    if VERBOSE
      posts.each_with_index do |p, i|
        new_num = i + 1
        if p.post_number != new_num
          puts "    post #{p.id}: #{p.post_number} → #{new_num} (#{p.created_at})"
        end
      end
    end

    unless DRY_RUN
      ActiveRecord::Base.transaction do
        # Pass 1: shift all post_numbers up. All the posts already have a post number. E.g., if
        # there are 15 posts and 10 comments, the posts will all already exist with ids 1..25. We need to assign
        # post numbers in that range, so this will set all current posts to be numbered 26..50. Then
        # we calculate what order they should be in, and renumber them back to 1..25 in chronological order.
        posts.each do |post|
          DB.exec("UPDATE posts SET post_number = #{post.post_number + new_highest}, sort_order = #{post.post_number + new_highest} WHERE id = #{post.id}")
        end

        # Pass 2: assign final sequential post_numbers in created_at order.
        posts.each_with_index do |post, i|
          new_number = i + 1
          DB.exec("UPDATE posts SET post_number = #{new_number}, sort_order = #{new_number} WHERE id = #{post.id}")
        end

        # Remap reply_to_post_number references using the old→new map.
        posts.each do |post|
          next if post.reply_to_post_number.nil?

          new_reply_to = old_to_new[post.reply_to_post_number]
          next unless new_reply_to
          next if new_reply_to == post.reply_to_post_number

          DB.exec("UPDATE posts SET reply_to_post_number = #{new_reply_to} WHERE id = #{post.id}")
        end

        # Update topics.highest_post_number.
        DB.exec("UPDATE topics SET highest_post_number = #{new_highest} WHERE id = #{topic_id}")

        # Cap topic_users.last_read_post_number at the new highest.
        DB.exec(<<~SQL)
          UPDATE topic_users
          SET last_read_post_number = LEAST(last_read_post_number, #{new_highest})
          WHERE topic_id = #{topic_id}
            AND last_read_post_number > #{new_highest}
        SQL
      end
    end

    reordered += 1

  rescue StandardError => e
    puts "  [topic #{topic_id}] ERROR: #{e.message.lines.first&.strip}"
    errors += 1
  end

  File.write(CHECKPOINT_FILE, topic_id.to_s) unless DRY_RUN || TOPIC_ID
  print "\r  #{idx + 1}/#{total} topics processed (#{reordered} reordered, #{skipped} skipped, #{errors} errors)"
end

puts ""

File.delete(CHECKPOINT_FILE) if !DRY_RUN && !TOPIC_ID && File.exist?(CHECKPOINT_FILE) && errors == 0

puts "", "Done#{DRY_RUN ? " (DRY RUN - no changes written)" : ""}."
puts "  Reordered: #{reordered}"
puts "  Skipped (already in order): #{skipped}"
puts "  Errors: #{errors}"
puts "  Checkpoint preserved for retry." if !DRY_RUN && errors > 0
