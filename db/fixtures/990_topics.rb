# frozen_string_literal: true

if !Rails.env.test?
  require 'seed_data/topics'

  topics_exist = Topic.where(<<~SQL).exists?
    id NOT IN (
      SELECT topic_id
      FROM categories
      WHERE topic_id IS NOT NULL
    )
  SQL

  SeedData::Topics.with_default_locale.create(include_welcome_topics: !topics_exist)
end
