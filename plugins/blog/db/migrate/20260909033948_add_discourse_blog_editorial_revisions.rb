# frozen_string_literal: true

class AddDiscourseBlogEditorialRevisions < ActiveRecord::Migration[8.0]
  def up
    create_table :discourse_blog_revisions do |table|
      table.bigint :publication_id, null: false
      table.bigint :source_topic_id, null: false
      table.bigint :creator_id, null: false
      table.jsonb :data, null: false, default: {}
      table.bigint :approver_id
      table.datetime :approved_at
      table.timestamps
    end
    add_index :discourse_blog_revisions, %i[publication_id id]
    change_table :discourse_blog_publications do |table|
      table.bigint :draft_topic_id
      table.bigint :discussion_topic_id
      table.bigint :published_revision_id
      table.bigint :submitted_revision_id
      table.bigint :approved_revision_id
      table.bigint :scheduled_revision_id
      table.bigint :scheduler_id
      table.datetime :scheduled_at
      table.datetime :last_published_at
      table.string :schedule_token
      table.text :schedule_error, null: false, default: ""
      table.jsonb :draft_metadata, null: false, default: {}
    end
    add_index :discourse_blog_publications, :draft_topic_id, unique: true
    add_index :discourse_blog_publications, :discussion_topic_id, unique: true

    return unless Migration::Helpers.existing_site?
    execute <<~SQL
      UPDATE discourse_blog_publications SET discussion_topic_id = topic_id WHERE published;
      INSERT INTO discourse_blog_revisions
        (publication_id, source_topic_id, creator_id, approver_id, approved_at, data, created_at, updated_at)
      SELECT publication.id, topic.id, post.user_id, COALESCE(publication.publisher_id, post.user_id),
        publication.published_at,
        jsonb_build_object(
          'title', topic.title, 'raw', post.raw, 'cooked', post.cooked,
          'path', publication.path, 'excerpt', publication.excerpt, 'featured', publication.featured,
          'published_at', publication.published_at,
          'author_name', COALESCE(NULLIF(author.name, ''), author.username),
          'image_url', COALESCE(upload.url, ''), 'tags', '[]'::jsonb
        ), publication.updated_at, publication.updated_at
      FROM discourse_blog_publications publication
      JOIN topics topic ON topic.id = publication.topic_id
      JOIN posts post ON post.topic_id = topic.id AND post.post_number = 1
      JOIN users author ON author.id = post.user_id
      LEFT JOIN uploads upload ON upload.id = topic.image_upload_id
      WHERE publication.published;
      UPDATE discourse_blog_publications publication
      SET published_revision_id = revision.id, last_published_at = publication.updated_at
      FROM discourse_blog_revisions revision WHERE revision.publication_id = publication.id;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Private editorial sources and public discussion identities cannot be safely downgraded."
  end
end
