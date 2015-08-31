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

    def map_message(row)
      user_id = @lookup.user_id_from_imported_user_id(row[:author_id]) || Discourse.system_user.id
      attachments = import_attachments(row, user_id)

      mapped = {
        id: "pm:#{row[:msg_id]}",
        user_id: user_id,
        created_at: Time.zone.at(row[:message_time]),
        raw: @text_processor.process_private_msg(row[:message_text], attachments)
      }

      if row[:root_msg_id] == 0
        map_first_message(row, mapped)
      else
        map_other_message(row, mapped)
      end
    end

    protected

    def import_attachments(row, user_id)
      if @settings.import_attachments && row[:attachment_count] > 0
        @attachment_importer.import_attachments(user_id, row[:msg_id])
      end
    end

    def map_first_message(row, mapped)
      mapped[:title] = CGI.unescapeHTML(row[:message_subject])
      mapped[:archetype] = Archetype.private_message
      mapped[:target_usernames] = get_usernames(row[:msg_id], row[:author_id])

      if mapped[:target_usernames].empty? # pm with yourself?
        puts "Private message without recipients. Skipping #{row[:msg_id]}: #{row[:message_subject][0..40]}"
        return nil
      end

      mapped
    end

    def map_other_message(row, mapped)
      parent_msg_id = "pm:#{row[:root_msg_id]}"
      parent = @lookup.topic_lookup_from_imported_post_id(parent_msg_id)

      if parent.blank?
        puts "Parent post #{parent_msg_id} doesn't exist. Skipping #{row[:msg_id]}: #{row[:message_subject][0..40]}"
        return nil
      end

      mapped[:topic_id] = parent[:topic_id]
      mapped
    end

    def get_usernames(msg_id, author_id)
      # Find the users who are part of this private message.
      # Found from the to_address of phpbb_privmsgs, by looking at
      # all the rows with the same root_msg_id.
      # to_address looks like this: "u_91:u_1234:u_200"
      # The "u_" prefix is discarded and the rest is a user_id.
      import_user_ids = @database.fetch_message_participants(msg_id, @settings.fix_private_messages)
                          .map { |r| r[:to_address].split(':') }
                          .flatten!.uniq.map! { |u| u[2..-1] }

      import_user_ids.map! do |import_user_id|
        import_user_id.to_s == author_id.to_s ? nil : @lookup.find_user_by_import_id(import_user_id).try(:username)
      end.compact
    end
  end
end
