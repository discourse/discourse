require "net/imap"

class Imap::Providers::Generic
  IMAP_LIBRARY = Net::IMAP

  def initialize(server, options = {})
    @server = server
    @port = options[:port] || 993
    @ssl = options[:ssl] || true
    @username = options[:username]
    @password = options[:password]
  end

  def imap
    @imap ||= IMAP_LIBRARY.new(@server, @port, @ssl, nil, false)
  end

  def all_uids
    imap.uid_search('ALL')
  end

  def uids_until(uid)
    imap.uid_search("UID 1:#{uid}")
  end

  def uids_from(uid)
    imap.uid_search("UID #{uid + 1}:*")
  end

  def connect!
    imap.login(@username, @password)
  end

  def labels
    extract_labels(list_mailboxes)
  end

  def select_mailbox(mailbox)
    imap.select(mailbox.name)
  end

  def mailbox_status(mailbox)
    # TODO: Server-to-client sync:
    #       - check mailbox validity
    #       - discover changes to old messages
    #       - fetch new messages
    imap.examine(mailbox.name)

    {
      uid_validity: imap.responses["UIDVALIDITY"][-1]
    }
  end

  def uid_search(uid)
    imap.uid_search(uid)
  end

  def emails(uids, fields = [])
    imap.uid_fetch(uids, fields).map do |email|
      attributes = {}

      fields.each do |field|
        attributes[field] = email.attr[field]
      end

      attributes
    end
  end

  def to_tag(label)
    label = DiscourseTagging.clean_tag(label.to_s)
    label if label != "all-mail" && label != "inbox" && label != "sent"
  end

  def disconnect!
    imap.logout
    imap.disconnect
  end

  private

  def list_mailboxes
    imap.list('', '*').map(&:name)
  end

  def extract_labels(mailboxes)
    labels = {}

    mailboxes.each do |name|
      if tag = to_tag(name)
        labels[tag] = name
      end
    end

    labels
  end

end
