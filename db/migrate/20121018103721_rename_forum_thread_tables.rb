class RenameForumThreadTables < ActiveRecord::Migration
  def change
    rename_table 'forum_threads', 'topics'
    rename_table 'forum_thread_link_clicks', 'topic_link_clicks'
    rename_table 'forum_thread_links', 'topic_links'
    rename_table 'forum_thread_users', 'topic_users'
    rename_table 'category_featured_threads', 'category_featured_topics'

    rename_column 'categories', 'forum_thread_id', 'topic_id'
    rename_column 'categories', 'top1_forum_thread_id', 'top1_topic_id'
    rename_column 'categories', 'top2_forum_thread_id', 'top2_topic_id'
    rename_column 'categories', 'forum_thread_count', 'topic_count'
    rename_column 'categories', 'threads_year', 'topics_year'
    rename_column 'categories', 'threads_month', 'topics_month'
    rename_column 'categories', 'threads_week', 'topics_week'


    rename_column 'category_featured_topics', 'forum_thread_id', 'topic_id'

    rename_column 'topic_link_clicks', 'forum_thread_link_id', 'topic_link_id'

    rename_column 'topic_links', 'forum_thread_id', 'topic_id'
    rename_column 'topic_links', 'link_forum_thread_id', 'link_topic_id'


    rename_column 'topic_users', 'forum_thread_id', 'topic_id'

    rename_column 'incoming_links', 'forum_thread_id', 'topic_id'

    rename_column 'notifications', 'forum_thread_id', 'topic_id'

    rename_column 'post_timings', 'forum_thread_id', 'topic_id'

    rename_column 'posts', 'forum_thread_id', 'topic_id'

    rename_column 'user_actions', 'target_forum_thread_id', 'target_topic_id'

    rename_column 'uploads', 'forum_thread_id', 'topic_id'
  end
end
