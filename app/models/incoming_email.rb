# frozen_string_literal: true

class IncomingEmail < ActiveRecord::Base
  self.ignored_columns += %w[imap_missing imap_sync imap_uid imap_uid_validity imap_group_id]

  belongs_to :user
  belongs_to :topic
  belongs_to :post

  validates :created_via, presence: true

  scope :errored, -> { where("NOT is_bounce AND error IS NOT NULL") }

  scope :addressed_to, ->(email) { where(<<~SQL, email: "%#{email}%") }
      incoming_emails.from_address = :email OR
      incoming_emails.to_addresses ILIKE :email OR
      incoming_emails.cc_addresses ILIKE :email
    SQL

  scope :addressed_to_user, ->(user) { where(<<~SQL, user_id: user.id) }
      EXISTS(
          SELECT 1
          FROM user_emails
          WHERE user_emails.user_id = :user_id AND
                (incoming_emails.from_address = user_emails.email OR
                 incoming_emails.to_addresses ILIKE '%' || user_emails.email || '%' OR
                 incoming_emails.cc_addresses ILIKE '%' || user_emails.email || '%')
      )
    SQL

  scope :without_raw, -> { select(self.column_names - ["raw"]) }

  def self.created_via_types
    @types ||=
      Enum.new(unknown: 0, handle_mail: 1, pop3_poll: 2, _deprecated_imap: 3, group_smtp: 4)
  end

  def as_mail_message
    @mail_message ||= Mail.new(self.raw)
  end

  def raw_headers
    as_mail_message.header.raw_source
  end

  def raw_body
    as_mail_message.body
  end

  def to_addresses_split
    self.to_addresses&.split(";") || []
  end

  def cc_addresses_split
    self.cc_addresses&.split(";") || []
  end

  def to_addresses=(to)
    to = to.map(&:downcase).join(";") if to.is_a?(Array)
    super(to)
  end

  def cc_addresses=(cc)
    cc = cc.map(&:downcase).join(";") if cc.is_a?(Array)
    super(cc)
  end

  def from_address=(from)
    from = from.first if from.is_a?(Array)
    super(from)
  end
end

# == Schema Information
#
# Table name: incoming_emails
#
#  id                :integer          not null, primary key
#  cc_addresses      :text
#  created_via       :integer          default(0), not null
#  error             :text
#  from_address      :text
#  is_auto_generated :boolean          default(FALSE)
#  is_bounce         :boolean          default(FALSE), not null
#  raw               :text
#  rejection_message :text
#  subject           :text
#  to_addresses      :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  message_id        :text
#  post_id           :integer
#  topic_id          :integer
#  user_id           :integer
#
# Indexes
#
#  index_incoming_emails_on_created_at     (created_at)
#  index_incoming_emails_on_error          (error)
#  index_incoming_emails_on_imap_group_id  (imap_group_id)
#  index_incoming_emails_on_imap_sync      (imap_sync)
#  index_incoming_emails_on_message_id     (message_id)
#  index_incoming_emails_on_post_id        (post_id)
#  index_incoming_emails_on_topic_id       (topic_id)
#  index_incoming_emails_on_user_id        (user_id) WHERE (user_id IS NOT NULL)
#
