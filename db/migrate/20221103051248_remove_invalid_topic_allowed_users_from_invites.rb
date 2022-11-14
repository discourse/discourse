# frozen_string_literal: true

class RemoveInvalidTopicAllowedUsersFromInvites < ActiveRecord::Migration[7.0]
  def up
    # We are getting all the topic_allowed_users records that
    # match an invited user, which is created as part of the invite
    # redemption flow. The original invite would _not_ have had a topic_invite
    # record, and the user should have been added to the topic in the brief
    # period between creation of the invited_users record and the update of
    # that record.
    #
    # Having > 2 topic allowed users disqualifies messages sent only
    # by the system or an admin to the user.
    subquery_sql = <<~SQL
      SELECT DISTINCT id
      FROM (
               SELECT tau.id, tau.user_id, COUNT(*) OVER (PARTITION BY tau.user_id)
               FROM topic_allowed_users tau
                    JOIN invited_users iu ON iu.user_id = tau.user_id
                    LEFT JOIN topic_invites ti ON ti.invite_id = iu.invite_id AND tau.topic_id = ti.topic_id
               WHERE ti.id IS NULL
                 AND tau.created_at BETWEEN iu.created_at AND iu.updated_at
                 AND iu.redeemed_at > '2022-10-27'
           ) AS matching_topic_allowed_users
      WHERE matching_topic_allowed_users.count > 2
    SQL

    # Back up the records we are going to change in case we are too
    # brutal, and for further inspection.
    #
    # TODO DROP this table (topic_allowed_users_backup_nov_2022) in a later migration.
    DB.exec(<<~SQL)
      CREATE TABLE topic_allowed_users_backup_nov_2022
      (
          id       INT NOT NULL,
          user_id  INT NOT NULL,
          topic_id INT NOT NULL
      );
      INSERT INTO topic_allowed_users_backup_nov_2022(id, user_id, topic_id)
      SELECT id, user_id, topic_id
      FROM topic_allowed_users
      WHERE id IN (
                      #{subquery_sql}
                  )
    SQL

    # Delete the invalid topic allowed users that should not be there.
    DB.query(<<~SQL)
      DELETE
      FROM topic_allowed_users
      WHERE id IN (
                      #{subquery_sql}
                  )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
