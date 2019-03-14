require "net/imap"

class Imap::Providers::Generic
  IMAP_LIBRARY = Net::IMAP

  attr_reader :remote_labels

  def initialize(server, options = {})
    @server = server
    @port = options[:port] || 993
    @ssl = options[:ssl] || true
    @username = options[:username]
    @password = options[:password]
    @remote_labels = []
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

    @remote_labels = extract_labels(list_mailboxes)
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

  def emails(mailbox, uids, fields = [])
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

  def tag_to_flag(tag)
    :Seen if tag == "seen"
  end

  def tag_to_label(tag, labels)
    labels[tag]
  end

  def disconnect!
    imap.logout
    imap.disconnect
  end

  def sync_flags(uid, topic, email)
    topic_tags = topic.tags.pluck(:name)

    flags = email["FLAGS"]
    new_flags = topic_tags.map { |tag| tag_to_flag(tag) }.reject(&:blank?)
    store(uid, "FLAGS", flags, new_flags)
  end

  private

  def store(uid, attribute, old_set, new_set)
    additions = new_set.reject { |val| old_set.include?(val) }
    add_attribute(attribute, uid, additions)

    removals = old_set.reject { |val| new_set.include?(val) }
    remove_attribute(attribute, uid, removals)
  end

  def add_attribute(attribute, uid, values)
    imap.uid_store(Array(uid), "+#{attribute}", values) if values.length > 0
  end

  def remove_attribute(attribute, uid, values)
    imap.uid_store(Array(uid), "-#{attribute}", values) if values.length > 0
  end

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
