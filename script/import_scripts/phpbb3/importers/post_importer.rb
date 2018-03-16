module ImportScripts::PhpBB3
  class PostImporter
    # @param lookup [ImportScripts::LookupContainer]
    # @param text_processor [ImportScripts::PhpBB3::TextProcessor]
    # @param attachment_importer [ImportScripts::PhpBB3::AttachmentImporter]
    # @param poll_importer [ImportScripts::PhpBB3::PollImporter]
    # @param permalink_importer [ImportScripts::PhpBB3::PermalinkImporter]
    # @param settings [ImportScripts::PhpBB3::Settings]
    def initialize(lookup, text_processor, attachment_importer, poll_importer, permalink_importer, settings)
      @lookup = lookup
      @text_processor = text_processor
      @attachment_importer = attachment_importer
      @poll_importer = poll_importer
      @permalink_importer = permalink_importer
      @settings = settings
    end

    def map_to_import_ids(rows)
      rows.map { |row| row[:post_id] }
    end

    def map_post(row)
      imported_user_id = row[:post_username].blank? ? row[:poster_id] : row[:post_username]
      user_id = @lookup.user_id_from_imported_user_id(imported_user_id) || -1
      is_first_post = row[:post_id] == row[:topic_first_post_id]

      attachments = import_attachments(row, user_id)

      mapped = {
        id: row[:post_id],
        user_id: user_id,
        created_at: Time.zone.at(row[:post_time]),
        raw: @text_processor.process_post(row[:post_text], attachments),
        import_topic_id: row[:topic_id]
      }

      if is_first_post
        map_first_post(row, mapped)
      else
        map_other_post(row, mapped)
      end
    end

    protected

    def import_attachments(row, user_id)
      if @settings.import_attachments && row[:post_attachment] > 0
        @attachment_importer.import_attachments(user_id, row[:post_id], row[:topic_id])
      end
    end

    def map_first_post(row, mapped)
      mapped[:category] = @lookup.category_id_from_imported_category_id(row[:forum_id])
      mapped[:title] = CGI.unescapeHTML(row[:topic_title]).strip[0...255]
      mapped[:pinned_at] = mapped[:created_at] unless row[:topic_type] == Constants::POST_NORMAL
      mapped[:pinned_globally] = row[:topic_type] == Constants::POST_GLOBAL
      mapped[:views] = row[:topic_views]
      mapped[:post_create_action] = proc do |post|
        @permalink_importer.create_for_topic(post.topic, row[:topic_id])
        @permalink_importer.create_for_post(post, row[:post_id])
        TopicViewItem.add(post.topic_id, row[:poster_ip], post.user_id, post.created_at, true)
      end

      add_poll(row, mapped) if @settings.import_polls
      mapped
    end

    def map_other_post(row, mapped)
      parent = @lookup.topic_lookup_from_imported_post_id(row[:topic_first_post_id])

      if parent.blank?
        puts "Parent post #{row[:topic_first_post_id]} doesn't exist. Skipping #{row[:post_id]}: #{row[:topic_title][0..40]}"
        return nil
      end

      mapped[:topic_id] = parent[:topic_id]
      mapped[:post_create_action] = proc do |post|
        @permalink_importer.create_for_post(post, row[:post_id])
        TopicViewItem.add(post.topic_id, row[:poster_ip], post.user_id, post.created_at, true)
      end

      mapped
    end

    def add_poll(row, mapped_post)
      return if row[:poll_title].blank?

      poll = Poll.new(row[:poll_title], row[:poll_max_options], row[:poll_end])
      mapped_poll = @poll_importer.map_poll(row[:topic_id], poll)

      if mapped_poll.present?
        mapped_post[:raw] = mapped_poll[:raw] << "\n" << mapped_post[:raw]
        mapped_post[:custom_fields] = mapped_poll[:custom_fields]
      end
    end
  end
end
