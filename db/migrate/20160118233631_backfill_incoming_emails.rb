class BackfillIncomingEmails < ActiveRecord::Migration[4.2]
  def up
    execute <<-SQL
      INSERT INTO incoming_emails (post_id, created_at, updated_at, user_id, topic_id, message_id, from_address, to_addresses, subject)
      SELECT posts.id
           , posts.created_at
           , posts.created_at
           , posts.user_id
           , posts.topic_id
           , array_to_string(regexp_matches(posts.raw_email, '^\s*Message-Id: .*<([^>]+)>', 'im'), '')
           , users.email
           , array_to_string(regexp_matches(array_to_string(regexp_matches(posts.raw_email, '^to:.+$', 'im'), ''), '[^<\s"''(]+@[^>\s"'')]+'), '')
           , topics.title
      FROM posts
      JOIN topics ON posts.topic_id = topics.id
      JOIN users ON posts.user_id = users.id
      WHERE posts.user_id IS NOT NULL
        AND posts.topic_id IS NOT NULL
        AND posts.via_email = 't'
        AND posts.raw_email ~* 'Message-Id'
      ORDER BY posts.id;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
