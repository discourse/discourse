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

  def emails(uids, fields)
    fields[fields.index("LABELS")] = X_GM_LABELS

    emails = super(uids, fields)

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

  def store(uid, attribute, old_set, new_set)
    attribute = X_GM_LABELS if attribute == "LABELS"
    super(uid, attribute, old_set, new_set)
  end

  def to_tag(label)
    # Label `\\Starred` is Gmail equivalent of :Flagged (both present)
    return "starred" if label == :Flagged

    label = label.to_s.gsub("[Gmail]/", "")
    super(label)
  end

  def tag_to_flag(tag)
    return :Flagged if tag == "starred"

    super(tag)
  end

  def tag_to_label(tag)
    return "\\Important" if tag == "important"
    return "\\Starred" if tag == "starred"

    super(tag)
  end
end
