require 'net/imap'

class Mailbox < ActiveRecord::Base
  belongs_to :group

  def self.refresh!(group)
    DistributedMutex.synchronize("group_refresh_mailboxes_#{group.id}") do
      Rails.logger.info("Refreshing mailboxes for group #{group.name} (ID = #{group.id}).")

      @imap = Net::IMAP.new(group.imap_server, group.imap_port, group.imap_ssl)
      @imap.login(group.email_username, group.email_password)

      old_mailboxes = group.mailboxes.map { |m| m.name if m.sync }.compact
      group.mailboxes.delete_all

      @imap.list('', '*').each do |m|
        next if m.attr.include?(:Noselect)

        Mailbox.create!(group: group,
                        name: m.name,
                        sync: old_mailboxes.include?(m.name))
      end
    end
  end

end

# == Schema Information
#
# Table name: mailboxes
#
#  id            :bigint           not null, primary key
#  group_id      :integer          not null
#  name          :string           not null
#  sync          :boolean          default(FALSE), not null
#  uid_validity  :integer          default(0), not null
#  last_seen_uid :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_mailboxes_on_group_id  (group_id)
#  index_mailboxes_on_name      (name)
#
