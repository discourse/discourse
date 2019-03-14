require_relative "imap_gmail_patch"

class Imap::Providers::Gmail < Imap::Providers::Generic
  X_GM_LABELS = "X-GM-LABELS"

  def imap
    @imap ||= begin
      imap = super
      apply_gmail_patch(imap)
      imap
    end
  end

  def to_tag(label)
    label = label.to_s.gsub("[Gmail]/", "")

    super(label)
  end

  def emails(mailbox, uids, fields = [])
    fields[fields.index("LABELS")] = X_GM_LABELS

    emails = super(mailbox, uids, fields)

    emails.each do |email|
      email["LABELS"] = Array(email["LABELS"])

      if email[X_GM_LABELS]
        email["LABELS"] << Array(email.delete(X_GM_LABELS))
        email["LABELS"].flatten!
      end

      email["LABELS"] << "\\Inbox" if mailbox.name == "INBOX"

      email["LABELS"].uniq!
    end

    emails
  end

  def sync_flags(uid, topic, email)
    super

    topic_tags = topic.tags.pluck(:name)

    labels = email["LABELS"]
    new_labels = topic_tags.map { |tag| tag_to_label(tag, @remote_labels) }.reject(&:blank?)
    new_labels << "\\Inbox" if topic.group_archived_messages.length == 0

    store(uid, X_GM_LABELS, labels, new_labels)
  end

  private

  def extract_labels(mailboxes)
    labels = super
    labels["important"] = "\\Important"
    labels
  end
end
