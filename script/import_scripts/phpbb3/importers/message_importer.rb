module ImportScripts::PhpBB3
  class MessageImporter
    # @param database [ImportScripts::PhpBB3::Database_3_0 | ImportScripts::PhpBB3::Database_3_1]
    # @param lookup [ImportScripts::LookupContainer]
    # @param text_processor [ImportScripts::PhpBB3::TextProcessor]
    # @param attachment_importer [ImportScripts::PhpBB3::AttachmentImporter]
    # @param settings [ImportScripts::PhpBB3::Settings]
    def initialize(database, lookup, text_processor, attachment_importer, settings)
      @database = database
      @lookup = lookup
      @text_processor = text_processor
      @attachment_importer = attachment_importer
      @settings = settings
    end

    def map_to_import_ids(rows)
      rows.map { |row| get_import_id(row[:msg_id]) }
    end

    def map_message(row)
      user_id = @lookup.user_id_from_imported_user_id(row[:author_id]) || Discourse.system_user.id
      attachments = import_attachments(row, user_id)

      mapped = {
        id: get_import_id(row[:msg_id]),
        user_id: user_id,
        created_at: Time.zone.at(row[:message_time]),
        raw: @text_processor.process_private_msg(row[:message_text], attachments)
      }

      root_user_ids = sorted_user_ids(row[:root_author_id], row[:root_to_address])
      current_user_ids = sorted_user_ids(row[:author_id], row[:to_address])
      topic_id = get_topic_id(row, root_user_ids, current_user_ids)

      if topic_id.blank?
        map_first_message(row, current_user_ids, mapped)
      else
        map_other_message(row, topic_id, mapped)
      end
    end

    protected

    RE_PREFIX = 're: '

    def import_attachments(row, user_id)
      if @settings.import_attachments && row[:attachment_count] > 0
        @attachment_importer.import_attachments(user_id, row[:msg_id])
      end
    end

    def map_first_message(row, current_user_ids, mapped)
      mapped[:title] = get_topic_title(row)
      mapped[:archetype] = Archetype.private_message
      mapped[:target_usernames] = get_recipient_usernames(row)
      mapped[:custom_fields] = { import_user_ids: current_user_ids.join(',') }

      if mapped[:target_usernames].empty?
        puts "Private message without recipients. Skipping #{row[:msg_id]}: #{row[:message_subject][0..40]}"
        return nil
      end

      mapped
    end

    def map_other_message(row, topic_id, mapped)
      mapped[:topic_id] = topic_id
      mapped
    end

    def get_recipient_user_ids(to_address)
      return [] if to_address.blank?

      # to_address looks like this: "u_91:u_1234:u_200"
      # The "u_" prefix is discarded and the rest is a user_id.
      user_ids = to_address.split(':')
      user_ids.uniq!
      user_ids.map! { |u| u[2..-1].to_i }
    end

    def get_recipient_usernames(row)
      import_user_ids = get_recipient_user_ids(row[:to_address])

      import_user_ids.map! do |import_user_id|
        @lookup.find_user_by_import_id(import_user_id).try(:username)
      end.compact
    end

    def get_topic_title(row)
      CGI.unescapeHTML(row[:message_subject])
    end

    def get_import_id(msg_id)
      "pm:#{msg_id}"
    end

    # Creates a sorted array consisting of the message's author and recipients.
    def sorted_user_ids(author_id, to_address)
      user_ids = get_recipient_user_ids(to_address)
      user_ids << author_id unless author_id.nil?
      user_ids.uniq!
      user_ids.sort!
    end

    def get_topic_id(row, root_user_ids, current_user_ids)
      if row[:root_msg_id] == 0 || root_user_ids != current_user_ids
        # Let's try to find an existing Discourse topic_id if this looks like a root message or
        # the user IDs of the root message are different from the current message.
        find_topic_id(row, current_user_ids)
      else
        # This appears to be a reply. Let's try to find the Discourse topic_id for this message.
        parent_msg_id = get_import_id(row[:root_msg_id])
        parent = @lookup.topic_lookup_from_imported_post_id(parent_msg_id)
        parent[:topic_id] unless parent.blank?
      end
    end

    # Tries to find a Discourse topic (private message) that has the same title as the current message.
    # The users involved in these messages must match too.
    def find_topic_id(row, current_user_ids)
      topic_title = get_topic_title(row).downcase
      topic_titles = [topic_title]
      topic_titles << topic_title[RE_PREFIX.length..-1] if topic_title.start_with?(RE_PREFIX)

      Post.select(:topic_id)
        .joins(:topic)
        .joins(:_custom_fields)
        .where(["LOWER(topics.title) IN (:titles) AND post_custom_fields.name = 'import_user_ids' AND post_custom_fields.value = :user_ids",
                { titles: topic_titles, user_ids: current_user_ids.join(',') }])
        .order('topics.created_at DESC')
        .first.try(:topic_id)
    end
  end
end
