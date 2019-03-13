require_dependency "imap_gmail_patch"

class Imap::Providers::Gmail < Imap::Providers::Generic
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

  def emails(uids, fields = [])
    fields[fields.index("LABELS")] = "X-GM-LABELS"

    emails = super(uids, fields)

    emails.each do |email|
      if email["X-GM-LABELS"]
        email["LABELS"] = email["LABELS"] + email.delete("X-GM-LABELS")
      end
    end

    emails
  end

  private

  def extract_labels(mailboxes)
    labels = super
    labels["important"] = "\\Important"
    labels
  end
end
