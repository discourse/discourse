# frozen_string_literal: true

class AddUserOptions < ActiveRecord::Migration[4.2]
  def up

    create_table :user_options, id: false do |t|
      t.integer :user_id, null: false
      t.boolean :email_always, null: false, default: false
      t.boolean :mailing_list_mode, null: false, default: false
      t.boolean :email_digests
      t.boolean :email_direct, null: false, default: true
      t.boolean :email_private_messages, null: false, default: true
      t.boolean :external_links_in_new_tab, null: false, default: false
      t.boolean :enable_quoting, null: false, default: true
      t.boolean :dynamic_favicon, null: false, default: false
      t.boolean :disable_jump_reply, null: false, default: false
      t.boolean :edit_history_public, null: false, default: false
      t.boolean :automatically_unpin_topics, null: false, default: true
      t.integer :digest_after_days
    end

    add_index :user_options, [:user_id], unique: true

    execute <<SQL
    INSERT INTO user_options (
            user_id,
            email_always,
            mailing_list_mode,
            email_digests,
            email_direct,
            email_private_messages,
            external_links_in_new_tab,
            enable_quoting,
            dynamic_favicon,
            disable_jump_reply,
            edit_history_public,
            automatically_unpin_topics,
            digest_after_days
    )
    SELECT  id,
            email_always,
            mailing_list_mode,
            email_digests,
            email_direct,
            COALESCE(email_private_messages,true),
            external_links_in_new_tab,
            enable_quoting,
            dynamic_favicon,
            disable_jump_reply,
            edit_history_public,
            automatically_unpin_topics,
            digest_after_days
    FROM users
SQL

    # these can not be removed until a bit later
    # if we remove them now all currently running unicorns will start erroring out
    #
    # remove_column :users, :email_always
    # remove_column :users, :mailing_list_mode
    # remove_column :users, :email_digests
    # remove_column :users, :email_direct
    # remove_column :users, :email_private_messages
    # remove_column :users, :external_links_in_new_tab
    # remove_column :users, :enable_quoting
    # remove_column :users, :dynamic_favicon
    # remove_column :users, :disable_jump_reply
    # remove_column :users, :edit_history_public
    # remove_column :users, :automatically_unpin_topics
    # remove_column :users, :digest_after_days
  end

  def down
    # we can not move backwards here cause columns
    # get removed an hour after the migration
    raise ActiveRecord::IrreversibleMigration
  end
end
