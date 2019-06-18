# frozen_string_literal: true

require 'seed_data/topics'

User.reset_column_information
Topic.reset_column_information
Post.reset_column_information

if !Rails.env.test?
  topics_exist = Topic.where(<<~SQL).exists?
    id NOT IN (
      SELECT topic_id
      FROM categories
      WHERE topic_id IS NOT NULL
    )
  SQL

  SeedData::Topics.with_default_locale.create(include_welcome_topics: !topics_exist)
end
