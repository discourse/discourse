# frozen_string_literal: true

module ImportScripts::PhpBB3
  class PostImporter
    # @param lookup [ImportScripts::LookupContainer]
    # @param text_processor [ImportScripts::PhpBB3::TextProcessor]
    # @param attachment_importer [ImportScripts::PhpBB3::AttachmentImporter]
    # @param poll_importer [ImportScripts::PhpBB3::PollImporter]
    # @param permalink_importer [ImportScripts::PhpBB3::PermalinkImporter]
    # @param settings [ImportScripts::PhpBB3::Settings]
    def initialize(
      lookup,
      text_processor,
      attachment_importer,
      poll_importer,
      permalink_importer,
      settings
    )
      @lookup = lookup
      @text_processor = text_processor
      @attachment_importer = attachment_importer
      @poll_importer = poll_importer
      @permalink_importer = permalink_importer
      @settings = settings
    end

    def map_to_import_ids(rows)
      rows.map { |row| @settings.prefix(row[:post_id]) }
    end

    def map_post(row)
      return if @settings.category_mappings.dig(row[:forum_id].to_s, :skip)

      imported_user_id =
        @settings.prefix(row[:post_username].blank? ? row[:poster_id] : row[:post_username])
      user_id = @lookup.user_id_from_imported_user_id(imported_user_id) || -1
      is_first_post = row[:post_id] == row[:topic_first_post_id]

      attachments = import_attachments(row, user_id)

      mapped = {
        id: @settings.prefix(row[:post_id]),
        user_id: user_id,
        created_at: Time.zone.at(row[:post_time]),
        raw: @text_processor.process_post(row[:post_text], attachments),
        import_topic_id: @settings.prefix(row[:topic_id]),
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
      poll_data = add_poll(row, mapped) if @settings.import_polls

      mapped[:category] = if category_mapping = @settings.category_mappings[row[:forum_id].to_s]
        category_mapping[:discourse_category_id] ||
          @lookup.category_id_from_imported_category_id(
            @settings.prefix(category_mapping[:target_category_id]),
          )
      else
        @lookup.category_id_from_imported_category_id(@settings.prefix(row[:forum_id]))
      end

      mapped[:title] = CGI.unescapeHTML(row[:topic_title]).strip[0...255]
      mapped[:pinned_at] = mapped[:created_at] unless row[:topic_type] == Constants::POST_NORMAL
      mapped[:pinned_globally] = row[:topic_type] == Constants::POST_GLOBAL
      mapped[:views] = row[:topic_views]
      mapped[:post_create_action] = proc do |post|
        if tags = @settings.tag_mappings[row[:forum_id].to_s].presence
          DiscourseTagging.tag_topic_by_names(post.topic, staff_guardian, tags)
        end
        @permalink_importer.create_for_topic(post.topic, row[:topic_id]) # skip @settings.prefix because ID is used in permalink generation
        @permalink_importer.create_for_post(post, row[:post_id]) # skip @settings.prefix because ID is used in permalink generation
        @poll_importer.update_poll(row[:topic_id], post, poll_data) if poll_data
        TopicViewItem.add(post.topic_id, row[:poster_ip], post.user_id, post.created_at, true)
      end

      mapped
    end

    def map_other_post(row, mapped)
      parent =
        @lookup.topic_lookup_from_imported_post_id(@settings.prefix(row[:topic_first_post_id]))

      if parent.blank?
        puts "Parent post #{@settings.prefix(row[:topic_first_post_id])} doesn't exist. Skipping #{@settings.prefix(row[:post_id])}: #{row[:topic_title][0..40]}"
        return nil
      end

      mapped[:topic_id] = parent[:topic_id]
      mapped[:post_create_action] = proc do |post|
        @permalink_importer.create_for_post(post, row[:post_id]) # skip @settings.prefix because ID is used in permalink generation
        TopicViewItem.add(post.topic_id, row[:poster_ip], post.user_id, post.created_at, true)
      end

      mapped
    end

    def add_poll(row, mapped_post)
      return if row[:poll_title].blank?

      poll_data = PollData.new(row[:poll_title], row[:poll_max_options], row[:poll_end])
      poll_raw = @poll_importer.create_raw(row[:topic_id], poll_data)
      return if poll_data.options.size < 2

      mapped_post[:raw] = poll_raw << "\n\n" << mapped_post[:raw]
      poll_data
    end

    def staff_guardian
      @_staff_guardian ||= Guardian.new(Discourse.system_user)
    end
  end
end
