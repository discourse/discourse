# frozen_string_literal: true

require_dependency "rake_helpers"

##
# This will create records in the new bookmarks table from PostAction
# records. The task is idempotent, it will not create additional bookmark
# records for PostActions that have already been created in the new table.
# You can provide a sync_limit for a smaller batch run.
#
desc "migrates old PostAction bookmarks to the new Bookmark model & table"
task "bookmarks:sync_to_table", [:sync_limit] => :environment do |_t, args|
  sync_limit = args[:sync_limit] || 0
  post_action_bookmarks = PostAction
    .select('post_actions.id', 'post_actions.post_id', 'posts.topic_id', 'post_actions.user_id')
    .where(post_action_type_id: PostActionType.types[:bookmark])
    .joins(:post)
    .where(deleted_at: nil)
    .joins('LEFT JOIN bookmarks ON bookmarks.post_id = post_actions.post_id AND bookmarks.user_id = post_actions.user_id')
    .joins('INNER JOIN topics ON topics.id = posts.topic_id')
    .where('bookmarks.id IS NULL')

  # if sync_limit is provided as an argument this will cap
  # the number of bookmarks that will be created in a run of
  # this task (for huge bookmark count communities)
  if sync_limit > 0
    post_action_bookmarks = post_action_bookmarks.limit(sync_limit)
  end

  post_action_bookmark_count = post_action_bookmarks.count('post_actions.id')
  i = 0

  bookmarks_to_create = []
  post_action_bookmarks.find_each(batch_size: 2000) do |pab|
    RakeHelpers.print_status_with_label("Creating post new bookmarks.......", i, post_action_bookmark_count)
    now = Time.zone.now
    bookmarks_to_create << {
      topic_id: pab.topic_id,
      post_id: pab.post_id,
      user_id: pab.user_id,
      created_at: now,
      updated_at: now
    }

    i += 1

    # once we get to 2000 records to create, insert them all and reset
    # the array and counter to make sure we don't have too many in memory
    if i >= 2000
      create_bookmarks(bookmarks_to_create)
      i = 0
      bookmarks_to_create = []
    end
  end

  # if there was < 2000 bookmarks this finishes off the last ones
  create_bookmarks(bookmarks_to_create)

  RakeHelpers.print_status_with_label("Bookmark creation complete!            ", i, post_action_bookmark_count)
  puts ""
end

def create_bookmarks(bookmarks_to_create)
  # this will ignore conflicts in the bookmarks table so
  # if the user already has a post bookmarked in the new way,
  # then we don't error and keep on truckin'
  #
  # we shouldn't have duplicates here at any rate because of
  # the above LEFT JOIN but best to be safe knowing this
  # won't blow up
  Bookmark.insert_all(bookmarks_to_create)
end
