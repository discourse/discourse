# frozen_string_literal: true

require 'csv'

module Jobs
  class ExportUserArchive < ::Jobs::Base
    sidekiq_options retry: false

    attr_accessor :current_user
    # note: contents provided entirely by user
    attr_accessor :extra

    COMPONENTS ||= %w(
      user_archive
      preferences
      auth_tokens
      auth_token_logs
      badges
      bookmarks
      category_preferences
      flags
      likes
      post_actions
      queued_posts
      visits
    )

    HEADER_ATTRS_FOR ||= HashWithIndifferentAccess.new(
      user_archive: ['topic_title', 'categories', 'is_pm', 'post', 'like_count', 'reply_count', 'url', 'created_at'],
      user_archive_profile: ['location', 'website', 'bio', 'views'],
      auth_tokens: ['id', 'auth_token_hash', 'prev_auth_token_hash', 'auth_token_seen', 'client_ip', 'user_agent', 'seen_at', 'rotated_at', 'created_at', 'updated_at'],
      auth_token_logs: ['id', 'action', 'user_auth_token_id', 'client_ip', 'auth_token_hash', 'created_at', 'path', 'user_agent'],
      badges: ['badge_id', 'badge_name', 'granted_at', 'post_id', 'seq', 'granted_manually', 'notification_id', 'featured_rank'],
      bookmarks: ['post_id', 'topic_id', 'post_number', 'link', 'name', 'created_at', 'updated_at', 'reminder_at', 'reminder_last_sent_at', 'reminder_set_at', 'auto_delete_preference'],
      category_preferences: ['category_id', 'category_names', 'notification_level', 'dismiss_new_timestamp'],
      flags: ['id', 'post_id', 'flag_type', 'created_at', 'updated_at', 'deleted_at', 'deleted_by', 'related_post_id', 'targets_topic', 'was_take_action'],
      likes: ['id', 'post_id', 'topic_id', 'post_number', 'created_at', 'updated_at', 'deleted_at', 'deleted_by'],
      post_actions: ['id', 'post_id', 'post_action_type', 'created_at', 'updated_at', 'deleted_at', 'deleted_by', 'related_post_id'],
      queued_posts: ['id', 'verdict', 'category_id', 'topic_id', 'post_raw', 'other_json'],
      visits: ['visited_at', 'posts_read', 'mobile', 'time_read'],
    )

    def execute(args)
      @current_user = User.find_by(id: args[:user_id])
      @extra = HashWithIndifferentAccess.new(args[:args]) if args[:args]
      @timestamp ||= Time.now.strftime("%y%m%d-%H%M%S")

      components = []

      COMPONENTS.each do |name|
        h = { name: name, method: :"#{name}_export" }
        h[:filetype] = :csv
        filetype_method = :"#{name}_filetype"
        if respond_to? filetype_method
          h[:filetype] = public_send(filetype_method)
        end
        condition_method = :"include_#{name}?"
        if respond_to? condition_method
          h[:skip] = !public_send(condition_method)
        end
        h[:filename] = name
        components.push(h)
      end

      export_title = 'user_archive'.titleize
      filename = "user_archive-#{@current_user.username}-#{@timestamp}"
      user_export = UserExport.create(file_name: filename, user_id: @current_user.id)

      filename = "#{filename}-#{user_export.id}"
      dirname = "#{UserExport.base_directory}/#{filename}"

      # ensure directory exists
      FileUtils.mkdir_p(dirname) unless Dir.exist?(dirname)

      # Generate a compressed CSV file
      zip_filename = nil
      begin
        components.each do |component|
          next if component[:skip]
          case component[:filetype]
          when :csv
            CSV.open("#{dirname}/#{component[:filename]}.csv", "w") do |csv|
              csv << get_header(component[:name])
              public_send(component[:method]) { |d| csv << d }
            end
          when :json
            File.open("#{dirname}/#{component[:filename]}.json", "w") do |file|
              file.write MultiJson.dump(public_send(component[:method]), indent: 4)
            end
          else
            raise 'unknown export filetype'
          end
        end

        zip_filename = Compression::Zip.new.compress(UserExport.base_directory, filename)
      ensure
        FileUtils.rm_rf(dirname)
      end

      # create upload
      upload = nil

      if File.exist?(zip_filename)
        File.open(zip_filename) do |file|
          upload = UploadCreator.new(
            file,
            File.basename(zip_filename),
            type: 'csv_export',
            for_export: 'true'
          ).create_for(@current_user.id)

          if upload.persisted?
            user_export.update_columns(upload_id: upload.id)
          else
            Rails.logger.warn("Failed to upload the file #{zip_filename}: #{upload.errors.full_messages}")
          end
        end

        File.delete(zip_filename)
      end
    ensure
      post = notify_user(upload, export_title)

      if user_export.present? && post.present?
        topic = post.topic
        user_export.update_columns(topic_id: topic.id)
        topic.update_status('closed', true, Discourse.system_user)
      end
    end

    def user_archive_export
      return enum_for(:user_archive_export) unless block_given?

      Post.includes(topic: :category)
        .where(user_id: @current_user.id)
        .select(:topic_id, :post_number, :raw, :like_count, :reply_count, :created_at)
        .order(:created_at)
        .with_deleted
        .each do |user_archive|
        yield get_user_archive_fields(user_archive)
      end
    end

    def user_archive_profile_export
      return enum_for(:user_archive_profile_export) unless block_given?

      UserProfile
        .where(user_id: @current_user.id)
        .select(:location, :website, :bio_raw, :views)
        .each do |user_profile|
        yield get_user_archive_profile_fields(user_profile)
      end
    end

    def preferences_export
      UserSerializer.new(@current_user, scope: guardian)
    end

    def preferences_filetype
      :json
    end

    def auth_tokens_export
      return enum_for(:auth_tokens) unless block_given?

      UserAuthToken
        .where(user_id: @current_user.id)
        .each do |token|
        yield [
          token.id,
          token.auth_token.to_s[0..4] + "...", # hashed and truncated
          token.prev_auth_token[0..4] + "...",
          token.auth_token_seen,
          token.client_ip,
          token.user_agent,
          token.seen_at,
          token.rotated_at,
          token.created_at,
          token.updated_at,
        ]
      end
    end

    def include_auth_token_logs?
      # SiteSetting.verbose_auth_token_logging
      UserAuthTokenLog.where(user_id: @current_user.id).exists?
    end

    def auth_token_logs_export
      return enum_for(:auth_token_logs) unless block_given?

      UserAuthTokenLog
        .where(user_id: @current_user.id)
        .each do |log|
        yield [
          log.id,
          log.action,
          log.user_auth_token_id,
          log.client_ip,
          log.auth_token.to_s[0..4] + "...", # hashed and truncated
          log.created_at,
          log.path,
          log.user_agent,
        ]
      end
    end

    def badges_export
      return enum_for(:badges_export) unless block_given?

      UserBadge
        .where(user_id: @current_user.id)
        .joins(:badge)
        .select(:badge_id, :granted_at, :post_id, :seq, :granted_by_id, :notification_id, :featured_rank)
        .order(:granted_at)
        .each do |ub|
        yield [
          ub.badge_id,
          ub.badge.display_name,
          ub.granted_at,
          ub.post_id,
          ub.seq,
          # Hide the admin's identity, simply indicate human or system
          User.human_user_id?(ub.granted_by_id),
          ub.notification_id,
          ub.featured_rank,
        ]
      end
    end

    def bookmarks_export
      return enum_for(:bookmarks_export) unless block_given?

      Bookmark
        .where(user_id: @current_user.id)
        .joins(:post)
        .order(:id)
        .each do |bkmk|
        link = ''
        if guardian.can_see_post?(bkmk.post)
          link = bkmk.post.full_url
        end
        yield [
          bkmk.post_id,
          bkmk.topic_id,
          bkmk.post&.post_number,
          link,
          bkmk.name,
          bkmk.created_at,
          bkmk.updated_at,
          bkmk.reminder_at,
          bkmk.reminder_last_sent_at,
          bkmk.reminder_set_at,
          Bookmark.auto_delete_preferences[bkmk.auto_delete_preference],
        ]
      end
    end

    def category_preferences_export
      return enum_for(:category_preferences_export) unless block_given?

      CategoryUser
        .where(user_id: @current_user.id)
        .select(:category_id, :notification_level, :last_seen_at)
        .each do |cu|
        yield [
          cu.category_id,
          piped_category_name(cu.category_id),
          NotificationLevels.all[cu.notification_level],
          cu.last_seen_at
        ]
      end
    end

    def flags_export
      return enum_for(:flags_export) unless block_given?

      PostAction
        .with_deleted
        .where(user_id: @current_user.id)
        .where(post_action_type_id: PostActionType.flag_types.values)
        .order(:created_at)
        .each do |pa|
        yield [
          pa.id,
          pa.post_id,
          PostActionType.flag_types[pa.post_action_type_id],
          pa.created_at,
          pa.updated_at,
          pa.deleted_at,
          self_or_other(pa.deleted_by_id),
          pa.related_post_id,
          pa.targets_topic,
          # renamed to 'was_take_action' to avoid possibility of thinking this is a synonym of agreed_at
          pa.staff_took_action,
        ]
      end
    end

    def likes_export
      return enum_for(:likes_export) unless block_given?
      PostAction
        .with_deleted
        .where(user_id: @current_user.id)
        .where(post_action_type_id: PostActionType.types[:like])
        .order(:created_at)
        .each do |pa|
        post = Post.with_deleted.find_by(id: pa.post_id)
        yield [
          pa.id,
          pa.post_id,
          post&.topic_id,
          post&.post_number,
          pa.created_at,
          pa.updated_at,
          pa.deleted_at,
          self_or_other(pa.deleted_by_id),
        ]
      end
    end

    def include_post_actions?
      # Most forums should not have post_action records other than flags and likes, but they are possible in historical oddities.
      PostAction
        .where(user_id: @current_user.id)
        .where.not(post_action_type_id: PostActionType.flag_types.values + [PostActionType.types[:like], PostActionType.types[:bookmark]])
        .exists?
    end

    def post_actions_export
      return enum_for(:likes_export) unless block_given?
      PostAction
        .with_deleted
        .where(user_id: @current_user.id)
        .where.not(post_action_type_id: PostActionType.flag_types.values + [PostActionType.types[:like], PostActionType.types[:bookmark]])
        .order(:created_at)
        .each do |pa|
        yield [
          pa.id,
          pa.post_id,
          PostActionType.types[pa.post_action_type] || pa.post_action_type,
          pa.created_at,
          pa.updated_at,
          pa.deleted_at,
          self_or_other(pa.deleted_by_id),
          pa.related_post_id,
        ]
      end
    end

    def queued_posts_export
      return enum_for(:queued_posts_export) unless block_given?

      # Most Reviewable fields staff-private, but post content needs to be exported.
      ReviewableQueuedPost
        .where(created_by: @current_user.id)
        .order(:created_at)
        .each do |rev|

        yield [
          rev.id,
          Reviewable.statuses[rev.status],
          rev.category_id,
          rev.topic_id,
          rev.payload['raw'],
          MultiJson.dump(rev.payload.slice(*queued_posts_payload_permitted_keys)),
        ]
      end
    end

    def visits_export
      return enum_for(:visits_export) unless block_given?

      UserVisit
        .where(user_id: @current_user.id)
        .order(visited_at: :asc)
        .each do |uv|
        yield [
          uv.visited_at,
          uv.posts_read,
          uv.mobile,
          uv.time_read,
        ]
      end
    end

    def get_header(entity)
      if entity == 'user_list'
        header_array = HEADER_ATTRS_FOR['user_list'] + HEADER_ATTRS_FOR['user_stats'] + HEADER_ATTRS_FOR['user_profile']
        header_array.concat(HEADER_ATTRS_FOR['user_sso']) if SiteSetting.enable_discourse_connect
        user_custom_fields = UserField.all
        if user_custom_fields.present?
          user_custom_fields.each do |custom_field|
            header_array.push("#{custom_field.name} (custom user field)")
          end
        end
        header_array.push("group_names")
      else
        header_array = HEADER_ATTRS_FOR[entity]
      end

      header_array
    end

    private

    def guardian
      @guardian ||= Guardian.new(@current_user)
    end

    def piped_category_name(category_id)
      return "-" unless category_id
      category = Category.find_by(id: category_id)
      return "#{category_id}" unless category
      categories = [category.name]
      while category.parent_category_id && category = category.parent_category
        categories << category.name
      end
      categories.reverse.join("|")
    end

    def self_or_other(user_id)
      if user_id.nil?
        nil
      elsif user_id == @current_user.id
        'self'
      else
        'other'
      end
    end

    def get_user_archive_fields(user_archive)
      user_archive_array = []
      topic_data = user_archive.topic
      user_archive = user_archive.as_json
      topic_data = Topic.with_deleted.find_by(id: user_archive['topic_id']) if topic_data.nil?
      return user_archive_array if topic_data.nil?

      categories = piped_category_name(topic_data.category_id)
      is_pm = topic_data.archetype == "private_message" ? I18n.t("csv_export.boolean_yes") : I18n.t("csv_export.boolean_no")
      url = "#{Discourse.base_url}/t/#{topic_data.slug}/#{topic_data.id}/#{user_archive['post_number']}"

      topic_hash = { "post" => user_archive['raw'], "topic_title" => topic_data.title, "categories" => categories, "is_pm" => is_pm, "url" => url }
      user_archive.merge!(topic_hash)

      HEADER_ATTRS_FOR['user_archive'].each do |attr|
        user_archive_array.push(user_archive[attr])
      end

      user_archive_array
    end

    def get_user_archive_profile_fields(user_profile)
      user_archive_profile = []

      HEADER_ATTRS_FOR['user_archive_profile'].each do |attr|
        data =
          if attr == 'bio'
            user_profile.attributes['bio_raw']
          else
            user_profile.attributes[attr]
          end

          user_archive_profile.push(data)
      end

      user_archive_profile
    end

    def queued_posts_payload_permitted_keys
      # Generated with:
      #
      # SELECT distinct json_object_keys(payload) from reviewables
      # where type = 'ReviewableQueuedPost' and (payload->'old_queued_post_id') IS NULL
      #
      # except raw, created_topic_id, created_post_id
      %w{
        composer_open_duration_msecs
        is_poll
        reply_to_post_number
        tags
        title
        typing_duration_msecs
      }
    end

    def notify_user(upload, export_title)
      post = nil

      if @current_user
        post = if upload.persisted?
          SystemMessage.create_from_system_user(
            @current_user,
            :csv_export_succeeded,
            download_link: UploadMarkdown.new(upload).attachment_markdown,
            export_title: export_title
          )
        else
          SystemMessage.create_from_system_user(@current_user, :csv_export_failed)
        end
      end

      post
    end
  end
end
