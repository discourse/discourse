User.reset_column_information
Topic.reset_column_information
Post.reset_column_information

if !Rails.env.test?
  seed_welcome_topics = !Topic.where(<<~SQL).exists?
    id NOT IN (
      SELECT topic_id
      FROM categories
      WHERE topic_id IS NOT NULL
    )
  SQL

  SeedData::Topics.with_default_locale.create(seed_welcome_topics)
end
