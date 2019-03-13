class AddMailboxes < ActiveRecord::Migration[5.2]
  def change
    add_column :groups, :email_smtp_server, :string
    add_column :groups, :email_smtp_port, :integer
    add_column :groups, :email_smtp_ssl, :boolean

    add_column :groups, :email_imap_server, :string
    add_column :groups, :email_imap_port, :integer
    add_column :groups, :email_imap_ssl, :boolean

    add_column :groups, :email_username, :string
    add_column :groups, :email_password, :string

    create_table :mailboxes do |t|
      t.integer :group_id, null: false
      t.string :name, null: false
      t.boolean :sync, default: false, null: false
      t.integer :uid_validity, default: 0, null: false
      t.integer :last_seen_uid, default: 0, null: false
      t.timestamps
    end

    add_index :mailboxes, [:group_id]
    add_index :mailboxes, [:name]
  end
end
