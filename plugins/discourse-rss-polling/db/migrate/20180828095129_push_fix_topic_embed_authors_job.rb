# frozen_string_literal: true

class PushFixTopicEmbedAuthorsJob < ActiveRecord::Migration[5.2]
  def up
    # This migrations was originally performed by the job
    # Jobs.enqueue("DiscourseRssPolling::FixTopicEmbedAuthors")
    #
    # It is now commented out to avoid brittle migrations.
    # This means that impacted instances that have not run the migration since 2018 will be sensitive to this change where topic embeds may point at the wrong posts
    #
    # This risk is acceptable given running a job in sidekiq during a migration is not recommended and more fragile
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
