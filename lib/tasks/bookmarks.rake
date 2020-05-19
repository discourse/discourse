# frozen_string_literal: true

require_dependency "rake_helpers"

##
# This will create records in the new bookmarks table from PostAction
# records. The task is idempotent, it will not create additional bookmark
# records for PostActions that have already been created in the new table.
# You can provide a sync_limit for a smaller batch run.
#
desc "migrates old PostAction bookmarks to the new Bookmark model & table"
task "bookmarks:sync_to_table" => :environment do |_t, args|
  bookmarks_to_create = []
  loop do
    # post action type id 1 is :bookmark. we do not need to OFFSET here for
    # paging because the WHERE bookmarks.id IS NULL clause handles this effectively,
    # because we do not get bookmarks back that have already been inserted
    post_action_bookmarks = DB.query(
      <<~SQL, type_id: 1
        SELECT post_actions.id, post_actions.post_id, posts.topic_id, post_actions.user_id
        FROM post_actions
        INNER JOIN posts ON posts.id = post_actions.post_id
        LEFT JOIN bookmarks ON bookmarks.post_id = post_actions.post_id AND bookmarks.user_id = post_actions.user_id
        INNER JOIN topics ON topics.id = posts.topic_id
        INNER JOIN users ON users.id = post_actions.user_id
        WHERE bookmarks.id IS NULL AND post_action_type_id = :type_id AND post_actions.deleted_at IS NULL AND posts.deleted_at IS NULL
        LIMIT 2000
      SQL
    )
    break if post_action_bookmarks.count.zero?

    post_action_bookmarks.each do |pab|
      now = Time.zone.now
      bookmarks_to_create << "(#{pab.topic_id}, #{pab.post_id}, #{pab.user_id}, '#{now}', '#{now}')"
    end

    create_bookmarks(bookmarks_to_create)
    bookmarks_to_create = []
  end # loop

  puts "Bookmark creation complete!"
end

def create_bookmarks(bookmarks_to_create)
  return if bookmarks_to_create.empty?

  # this will ignore conflicts in the bookmarks table so
  # if the user already has a post bookmarked in the new way,
  # then we don't error and keep on truckin'
  #
  # we shouldn't have duplicates here at any rate because of
  # the above LEFT JOIN but best to be safe knowing this
  # won't blow up
  #
  DB.exec(
    <<~SQL
      INSERT INTO bookmarks (topic_id, post_id, user_id, created_at, updated_at)
      VALUES #{bookmarks_to_create.join(",\n")}
      ON CONFLICT DO NOTHING
    SQL
  )
end
