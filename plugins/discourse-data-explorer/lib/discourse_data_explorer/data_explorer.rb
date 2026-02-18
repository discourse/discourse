# frozen_string_literal: true

module DiscourseDataExplorer
  module DataExplorer
    # Used for ftype calls, see https://www.rubydoc.info/gems/pg/0.17.1/PG%2FResult:ftype
    # and /usr/include/postgresql/server/catalog/pg_type_d.h
    PG_TYPE_OID_JSON = 114

    # Run a data explorer query on the currently connected database.
    #
    # @param [Query] query the Query object to run
    # @param [Hash] params the colon-style query parameters for the query
    # @param [Hash] opts hash of options
    #   explain - include a query plan in the result
    # @return [Hash]
    #   error - any exception that was raised in the execution. Check this
    #     first before looking at any other fields.
    #   pg_result - the PG::Result object
    #   duration_nanos - the query duration, in nanoseconds
    #   explain - the query
    def self.run_query(query, req_params = {}, opts = {})
      # Safety checks
      # see test 'doesn't allow you to modify the database #2'
      if query.sql =~ /;/
        err = ValidationError.new(I18n.t("js.errors.explorer.no_semicolons"))
        return { error: err, duration_nanos: 0 }
      end

      query_args = {}
      begin
        query_args = query.cast_params(req_params, opts)
      rescue ValidationError => e
        return { error: e, duration_nanos: 0 }
      end

      time_start, time_end, explain, err, result = nil
      begin
        ActiveRecord::Base.connection.transaction do
          # Setting transaction to read only prevents shoot-in-foot actions like SELECT FOR UPDATE
          # see test 'doesn't allow you to modify the database #1'
          DB.exec "SET TRANSACTION READ ONLY"
          # Set a statement timeout so we can't tie up the server
          DB.exec "SET LOCAL statement_timeout = 10000"

          # SQL comments are for the benefits of the slow queries log
          started_by = opts[:current_user]&.username
          sql = <<~SQL
            /*
            * DiscourseDataExplorer Query
            * Query: /admin/plugins/discourse-data-explorer/queries/#{query.id}
            #{"* Started by: #{started_by}" if started_by}
            */
            WITH query AS (
            #{query.sql}
            ) SELECT * FROM query
            LIMIT #{opts[:limit] || SiteSetting.data_explorer_query_result_limit}
          SQL

          time_start = Time.now

          # Using MiniSql::InlineParamEncoder directly instead of DB.param_encoder because current implementation of
          # DB.param_encoder is meant for SQL fragments and not an entire SQL string.
          sql =
            MiniSql::InlineParamEncoder.new(ActiveRecord::Base.connection.raw_connection).encode(
              sql,
              query_args,
            )

          result = ActiveRecord::Base.connection.raw_connection.async_exec(sql)
          result.check # make sure it's done
          time_end = Time.now

          if opts[:explain]
            explain =
              DB
                .query_hash("EXPLAIN #{query.sql}", query_args)
                .map { |row| row["QUERY PLAN"] }.join "\n"
          end

          # All done. Issue a rollback anyways, just in case
          # see test 'doesn't allow you to modify the database #1'
          raise ActiveRecord::Rollback
        end
      rescue Exception => ex
        err = ex
        time_end = Time.now
      end

      {
        error: err,
        pg_result: result,
        duration_secs: time_end - time_start,
        explain: explain,
        params_full: query_args,
      }
    end

    def self.extra_data_pluck_fields
      @extra_data_pluck_fields ||= {
        user: {
          class: User,
          fields: %i[id username uploaded_avatar_id],
          serializer: BasicUserSerializer,
        },
        badge: {
          class: Badge,
          fields: %i[id name badge_type_id description icon],
          include: [:badge_type],
          serializer: SmallBadgeSerializer,
        },
        post: {
          class: Post,
          fields: %i[id topic_id post_number cooked user_id],
          include: [:user],
          serializer: SmallPostWithExcerptSerializer,
        },
        topic: {
          class: Topic,
          fields: %i[id title slug posts_count locale],
          serializer: BasicTopicSerializer,
        },
        tag_group: {
          class: TagGroup,
          fields: %i[id name],
          only: %i[id name],
        },
        group: {
          class: Group,
          ignore: true,
        },
        category: {
          class: Category,
          ignore: true,
        },
        reltime: {
          ignore: true,
        },
        html: {
          ignore: true,
        },
        json: {
          ignore: true,
        },
      }
    end

    def self.column_regexes
      @column_regexes ||=
        extra_data_pluck_fields
          .map { |key, val| /(#{val[:class].to_s.underscore})_id$/ if val[:class] }
          .compact
    end

    def self.add_extra_data(pg_result)
      needed_classes = {}
      ret = {}
      col_map = {}
      pg_result.fields.each_with_index do |col, idx|
        rgx = column_regexes.find { |r| r.match col }
        if rgx
          cls = (rgx.match col)[1].to_sym
          needed_classes[cls] ||= []
          needed_classes[cls] << idx
        elsif col =~ /^(\w+)\$/
          cls = $1.to_sym
          needed_classes[cls] ||= []
          needed_classes[cls] << idx
        elsif col =~ /^\w+_url$/
          col_map[idx] = "url"
        elsif col =~ /^\w+_payload$/ || col == "payload" || pg_result.ftype(idx) == PG_TYPE_OID_JSON
          col_map[idx] = "json"
        end
      end

      needed_classes.each do |cls, column_nums|
        next if column_nums.blank?
        support_info = extra_data_pluck_fields[cls]
        next unless support_info

        column_nums.each { |col_n| col_map[col_n] = cls }

        if support_info[:ignore]
          ret[cls] = []
          next
        end

        ids = Set.new
        column_nums.each { |col_n| ids.merge(pg_result.column_values(col_n)) }
        ids.delete nil
        ids.map! &:to_i

        object_class = support_info[:class]
        all_objs = object_class
        all_objs = all_objs.with_deleted if all_objs.respond_to? :with_deleted
        all_objs =
          all_objs
            .select(support_info[:fields])
            .where(id: ids.to_a.sort)
            .includes(support_info[:include])
            .order(:id)

        opts = { each_serializer: support_info[:serializer] }
        opts[:only] = support_info[:only] if support_info[:only]
        ret[cls] = ActiveModel::ArraySerializer.new(all_objs, **opts)
      end
      [ret, col_map]
    end

    def self.sensitive_column_names
      %w[
        #_IP_Addresses
        topic_views.ip_address
        users.ip_address
        users.registration_ip_address
        incoming_links.ip_address
        topic_link_clicks.ip_address
        user_histories.ip_address
        #_Emails
        email_tokens.email
        users.email
        invites.email
        user_histories.email
        email_logs.to_address
        posts.raw_email
        badge_posts.raw_email
        #_Secret_Tokens
        email_tokens.token
        email_logs.reply_key
        api_keys.key
        site_settings.value
        users.auth_token
        users.password_hash
        users.salt
        #_Authentication_Info
        user_open_ids.email
        oauth2_user_infos.uid
        oauth2_user_infos.email
        facebook_user_infos.facebook_user_id
        facebook_user_infos.email
        twitter_user_infos.twitter_user_id
        github_user_infos.github_user_id
        single_sign_on_records.external_email
        single_sign_on_records.external_id
        google_user_infos.google_user_id
        google_user_infos.email
      ]
    end

    def self.schema
      # No need to expire this, because the server processes get restarted on upgrade
      # refer user to http://www.postgresql.org/docs/9.3/static/datatype.html
      @schema ||=
        begin
          results = DB.query_hash <<~SQL
            select
              c.column_name column_name,
              c.data_type data_type,
              c.character_maximum_length character_maximum_length,
              c.is_nullable is_nullable,
              c.column_default column_default,
              c.table_name table_name,
              pgd.description column_desc
            from INFORMATION_SCHEMA.COLUMNS c
            inner join pg_catalog.pg_statio_all_tables st on (c.table_schema = st.schemaname and c.table_name = st.relname)
            left outer join pg_catalog.pg_description pgd on (pgd.objoid = st.relid and pgd.objsubid = c.ordinal_position)
            where c.table_schema = 'public'
            ORDER BY c.table_name, c.ordinal_position
          SQL

          by_table = {}
          # Massage the results into a nicer form
          results.each do |hash|
            full_col_name = "#{hash["table_name"]}.#{hash["column_name"]}"

            if hash["is_nullable"] == "YES"
              hash["is_nullable"] = true
            else
              hash.delete("is_nullable")
            end
            clen = hash.delete "character_maximum_length"
            dt = hash["data_type"]
            if hash["column_name"] == "id"
              hash["data_type"] = "serial"
              hash["primary"] = true
            elsif dt == "character varying"
              hash["data_type"] = "varchar(#{clen.to_i})"
            elsif dt == "timestamp without time zone"
              hash["data_type"] = "timestamp"
            elsif dt == "double precision"
              hash["data_type"] = "double"
            end
            default = hash["column_default"]
            if default.nil? || default =~ /^nextval\(/
              hash.delete "column_default"
            elsif default =~ /^'(.*)'::(character varying|text)/
              hash["column_default"] = $1
            end
            hash.delete("column_desc") unless hash["column_desc"]

            hash["sensitive"] = true if sensitive_column_names.include? full_col_name
            hash["enum"] = enum_info[full_col_name] if enum_info.include? full_col_name
            if denormalized_columns.include? full_col_name
              hash["denormal"] = denormalized_columns[full_col_name]
            end
            fkey = fkey_info(hash["table_name"], hash["column_name"])
            hash["fkey_info"] = fkey if fkey

            table_name = hash.delete("table_name")
            by_table[table_name] ||= []
            by_table[table_name] << hash
          end

          # this works for now, but no big loss if the tables aren't quite sorted
          favored_order = %w[
            posts
            topics
            users
            categories
            badges
            groups
            notifications
            post_actions
            site_settings
          ]
          sorted_by_table = {}
          favored_order.each { |tbl| sorted_by_table[tbl] = by_table[tbl] }
          by_table.keys.sort.each do |tbl|
            next if favored_order.include? tbl
            sorted_by_table[tbl] = by_table[tbl]
          end
          sorted_by_table
        end
    end

    def self.enums
      return @enums if @enums

      @enums = {
        "application_requests.req_type": ApplicationRequest.req_types,
        "badges.badge_type_id": Enum.new(:gold, :silver, :bronze, start: 1),
        "bookmarks.auto_delete_preference": Bookmark.auto_delete_preferences,
        "category_groups.permission_type": CategoryGroup.permission_types,
        "category_users.notification_level": CategoryUser.notification_levels,
        "directory_items.period_type": DirectoryItem.period_types,
        "email_change_requests.change_state": EmailChangeRequest.states,
        "groups.id": Group::AUTO_GROUPS,
        "groups.mentionable_level": Group::ALIAS_LEVELS,
        "groups.messageable_level": Group::ALIAS_LEVELS,
        "groups.members_visibility_level": Group.visibility_levels,
        "groups.visibility_level": Group.visibility_levels,
        "groups.default_notification_level": GroupUser.notification_levels,
        "group_histories.action": GroupHistory.actions,
        "group_users.notification_level": GroupUser.notification_levels,
        "invites.emailed_status": Invite.emailed_status_types,
        "notifications.notification_type": Notification.types,
        "polls.results": Poll.results,
        "polls.status": Poll.statuses,
        "polls.type": Poll.types,
        "polls.visibility": Poll.visibilities,
        "post_action_types.id": PostActionType.types,
        "post_actions.post_action_type_id": PostActionType.types,
        "posts.cook_method": Post.cook_methods,
        "posts.hidden_reason_id": Post.hidden_reasons,
        "posts.post_type": Post.types,
        "reviewables.status": Reviewable.statuses,
        "reviewable_histories.reviewable_history_type": ReviewableHistory.types,
        "reviewable_scores.status": ReviewableScore.statuses,
        "screened_emails.action_type": ScreenedEmail.actions,
        "screened_ip_addresses.action_type": ScreenedIpAddress.actions,
        "screened_urls.action_type": ScreenedUrl.actions,
        "search_logs.search_result_type": SearchLog.search_result_types,
        "search_logs.search_type": SearchLog.search_types,
        "site_settings.data_type": SiteSetting.types,
        "skipped_email_logs.reason_type": SkippedEmailLog.reason_types,
        "tag_group_permissions.permission_type": TagGroupPermission.permission_types,
        "theme_fields.type_id": ThemeField.types,
        "theme_settings.data_type": ThemeSetting.types,
        "topic_timers.status_type": TopicTimer.types,
        "topic_users.notification_level": TopicUser.notification_levels,
        "topic_users.notifications_reason_id": TopicUser.notification_reasons,
        "uploads.verification_status": Upload.verification_statuses,
        "user_actions.action_type": UserAction.types,
        "user_histories.action": UserHistory.actions,
        "user_options.email_previous_replies": UserOption.previous_replies_type,
        "user_options.like_notification_frequency": UserOption.like_notification_frequency_type,
        "user_options.text_size_key": UserOption.text_sizes,
        "user_options.title_count_mode_key": UserOption.title_count_modes,
        "user_options.email_level": UserOption.email_level_types,
        "user_options.email_messages_level": UserOption.email_level_types,
        "user_second_factors.method": UserSecondFactor.methods,
        "user_security_keys.factor_type": UserSecurityKey.factor_types,
        "users.trust_level": TrustLevel.levels,
        "watched_words.action": WatchedWord.actions,
        "web_hooks.content_type": WebHook.content_types,
        "web_hooks.last_delivery_status": WebHook.last_delivery_statuses,
      }.with_indifferent_access

      # QueuedPost is removed in recent Discourse releases
      @enums["queued_posts.state"] = QueuedPost.states if defined?(QueuedPost)

      @enums
    end

    def self.enum_info
      @enum_info ||=
        begin
          enum_info = {}
          enums.map do |key, enum|
            # https://stackoverflow.com/questions/10874356/reverse-a-hash-in-ruby
            enum_info[key] = Hash[enum.to_a.map(&:reverse)]
          end
          enum_info
        end
    end

    def self.fkey_info(table, column)
      full_name = "#{table}.#{column}"

      if fkey_defaults[column]
        fkey_defaults[column]
      elsif column =~ /_by_id$/ || column =~ /_user_id$/
        :users
      elsif foreign_keys[full_name]
        foreign_keys[full_name]
      else
        nil
      end
    end

    def self.foreign_keys
      @fkey_columns ||= {
        "posts.last_editor_id": :users,
        "posts.version": :"post_revisions.number",
        "topics.featured_user1_id": :users,
        "topics.featured_user2_id": :users,
        "topics.featured_user3_id": :users,
        "topics.featured_user4_id": :users,
        "topics.featured_user5_id": :users,
        "users.seen_notification_id": :notifications,
        "users.uploaded_avatar_id": :uploads,
        "users.primary_group_id": :groups,
        "categories.latest_post_id": :posts,
        "categories.latest_topic_id": :topics,
        "categories.parent_category_id": :categories,
        "badges.badge_grouping_id": :badge_groupings,
        "post_actions.related_post_id": :posts,
        "color_scheme_colors.color_scheme_id": :color_schemes,
        "color_schemes.versioned_id": :color_schemes,
        "incoming_links.incoming_referer_id": :incoming_referers,
        "incoming_referers.incoming_domain_id": :incoming_domains,
        "post_replies.reply_id": :posts,
        "quoted_posts.quoted_post_id": :posts,
        "topic_link_clicks.topic_link_id": :topic_links,
        "topic_link_clicks.link_topic_id": :topics,
        "topic_link_clicks.link_post_id": :posts,
        "user_actions.target_topic_id": :topics,
        "user_actions.target_post_id": :posts,
        "user_avatars.custom_upload_id": :uploads,
        "user_avatars.gravatar_upload_id": :uploads,
        "user_badges.notification_id": :notifications,
        "user_profiles.card_image_badge_id": :badges,
      }.with_indifferent_access
    end

    def self.fkey_defaults
      @fkey_defaults ||= {
        user_id: :users,
        # :*_by_id    => :users,
        # :*_user_id  => :users,
        category_id: :categories,
        group_id: :groups,
        post_id: :posts,
        post_action_id: :post_actions,
        topic_id: :topics,
        upload_id: :uploads,
      }.with_indifferent_access
    end

    def self.denormalized_columns
      {
        "posts.reply_count": :post_replies,
        "posts.quote_count": :quoted_posts,
        "posts.incoming_link_count": :topic_links,
        "posts.word_count": :posts,
        "posts.avg_time": :post_timings,
        "posts.reads": :post_timings,
        "posts.like_score": :post_actions,
        "posts.like_count": :post_actions,
        "posts.bookmark_count": :post_actions,
        "posts.vote_count": :post_actions,
        "posts.off_topic_count": :post_actions,
        "posts.notify_moderators_count": :post_actions,
        "posts.spam_count": :post_actions,
        "posts.illegal_count": :post_actions,
        "posts.inappropriate_count": :post_actions,
        "posts.notify_user_count": :post_actions,
        "topics.views": :topic_views,
        "topics.posts_count": :posts,
        "topics.reply_count": :posts,
        "topics.incoming_link_count": :topic_links,
        "topics.moderator_posts_count": :posts,
        "topics.participant_count": :posts,
        "topics.word_count": :posts,
        "topics.last_posted_at": :posts,
        "topics.last_post_user_idt": :posts,
        "topics.avg_time": :post_timings,
        "topics.highest_post_number": :posts,
        "topics.image_url": :posts,
        "topics.excerpt": :posts,
        "topics.like_count": :post_actions,
        "topics.bookmark_count": :post_actions,
        "topics.vote_count": :post_actions,
        "topics.off_topic_count": :post_actions,
        "topics.notify_moderators_count": :post_actions,
        "topics.spam_count": :post_actions,
        "topics.illegal_count": :post_actions,
        "topics.inappropriate_count": :post_actions,
        "topics.notify_user_count": :post_actions,
        "categories.topic_count": :topics,
        "categories.post_count": :posts,
        "categories.latest_post_id": :posts,
        "categories.latest_topic_id": :topics,
        "categories.description": :posts,
        "categories.read_restricted": :category_groups,
        "categories.topics_year": :topics,
        "categories.topics_month": :topics,
        "categories.topics_week": :topics,
        "categories.topics_day": :topics,
        "categories.posts_year": :posts,
        "categories.posts_month": :posts,
        "categories.posts_week": :posts,
        "categories.posts_day": :posts,
        "badges.grant_count": :user_badges,
        "groups.user_count": :group_users,
        "directory_items.likes_received": :post_actions,
        "directory_items.likes_given": :post_actions,
        "directory_items.topics_entered": :user_stats,
        "directory_items.days_visited": :user_stats,
        "directory_items.posts_read": :user_stats,
        "directory_items.topic_count": :topics,
        "directory_items.post_count": :posts,
        "post_search_data.search_data": :posts,
        "top_topics.yearly_posts_count": :posts,
        "top_topics.monthly_posts_count": :posts,
        "top_topics.weekly_posts_count": :posts,
        "top_topics.daily_posts_count": :posts,
        "top_topics.yearly_views_count": :topic_views,
        "top_topics.monthly_views_count": :topic_views,
        "top_topics.weekly_views_count": :topic_views,
        "top_topics.daily_views_count": :topic_views,
        "top_topics.yearly_likes_count": :post_actions,
        "top_topics.monthly_likes_count": :post_actions,
        "top_topics.weekly_likes_count": :post_actions,
        "top_topics.daily_likes_count": :post_actions,
        "top_topics.yearly_op_likes_count": :post_actions,
        "top_topics.monthly_op_likes_count": :post_actions,
        "top_topics.weekly_op_likes_count": :post_actions,
        "top_topics.daily_op_likes_count": :post_actions,
        "top_topics.all_score": :posts,
        "top_topics.yearly_score": :posts,
        "top_topics.monthly_score": :posts,
        "top_topics.weekly_score": :posts,
        "top_topics.daily_score": :posts,
        "topic_links.clicks": :topic_link_clicks,
        "topic_search_data.search_data": :topics,
        "topic_users.liked": :post_actions,
        "topic_users.bookmarked": :post_actions,
        "user_stats.posts_read_count": :post_timings,
        "user_stats.topic_reply_count": :posts,
        "user_stats.first_post_created_at": :posts,
        "user_stats.post_count": :posts,
        "user_stats.topic_count": :topics,
        "user_stats.likes_given": :post_actions,
        "user_stats.likes_received": :post_actions,
        "user_search_data.search_data": :user_profiles,
        "users.last_posted_at": :posts,
        "users.previous_visit_at": :user_visits,
      }.with_indifferent_access
    end
  end
end
