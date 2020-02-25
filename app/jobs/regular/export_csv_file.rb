# frozen_string_literal: true

require 'csv'

module Jobs

  class ExportCsvFile < ::Jobs::Base
    sidekiq_options retry: false

    HEADER_ATTRS_FOR ||= HashWithIndifferentAccess.new(
      user_archive: ['topic_title', 'categories', 'is_pm', 'post', 'like_count', 'reply_count', 'url', 'created_at'],
      user_list: ['id', 'name', 'username', 'email', 'title', 'created_at', 'last_seen_at', 'last_posted_at', 'last_emailed_at', 'trust_level', 'approved', 'suspended_at', 'suspended_till', 'silenced_till', 'active', 'admin', 'moderator', 'ip_address', 'staged', 'secondary_emails'],
      user_stats: ['topics_entered', 'posts_read_count', 'time_read', 'topic_count', 'post_count', 'likes_given', 'likes_received'],
      user_profile: ['location', 'website', 'views'],
      user_sso: ['external_id', 'external_email', 'external_username', 'external_name', 'external_avatar_url'],
      staff_action: ['staff_user', 'action', 'subject', 'created_at', 'details', 'context'],
      screened_email: ['email', 'action', 'match_count', 'last_match_at', 'created_at', 'ip_address'],
      screened_ip: ['ip_address', 'action', 'match_count', 'last_match_at', 'created_at'],
      screened_url: ['domain', 'action', 'match_count', 'last_match_at', 'created_at'],
      report: ['date', 'value']
    )

    def execute(args)
      @entity = args[:entity]
      @extra = HashWithIndifferentAccess.new(args[:args]) if args[:args]
      @current_user = User.find_by(id: args[:user_id])

      export_method = :"#{@entity}_export"
      raise Discourse::InvalidParameters.new(:entity) unless respond_to?(export_method)

      file_name_prefix = if @entity == "user_archive"
        "#{@entity.split('_').join('-')}-#{@current_user.username}-#{Time.now.strftime("%y%m%d-%H%M%S")}"
      elsif @entity == "report" && @extra[:name].present?
        "#{@extra[:name].split('_').join('-')}-#{Time.now.strftime("%y%m%d-%H%M%S")}"
      else
        "#{@entity.split('_').join('-')}-#{Time.now.strftime("%y%m%d-%H%M%S")}"
      end

      export_title = if @entity == "report" && @extra[:name].present?
        I18n.t("reports.#{@extra[:name]}.title")
      else
        @entity.split('_').join(' ').titleize
      end

      user_export = UserExport.create(file_name: file_name_prefix, user_id: @current_user.id)
      file_name = "#{file_name_prefix}-#{user_export.id}.csv"
      absolute_path = "#{UserExport.base_directory}/#{file_name}"

      # ensure directory exists
      FileUtils.mkdir_p(UserExport.base_directory) unless Dir.exists?(UserExport.base_directory)

      # Generate a compressed CSV file
      begin
        CSV.open(absolute_path, "w") do |csv|
          csv << get_header if @entity != "report"
          public_send(export_method).each { |d| csv << d }
        end
        compressed_file_path = Compression::Zip.new.compress(UserExport.base_directory, file_name)
      ensure
        File.delete(absolute_path)
      end

      # create upload
      upload = nil

      if File.exist?(compressed_file_path)
        File.open(compressed_file_path) do |file|
          upload = UploadCreator.new(
            file,
            File.basename(compressed_file_path),
            type: 'csv_export',
            for_export: 'true'
          ).create_for(@current_user.id)

          if upload.persisted?
            user_export.update_columns(upload_id: upload.id)
          else
            Rails.logger.warn("Failed to upload the file #{compressed_file_path}")
          end
        end

        File.delete(compressed_file_path)
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

    def user_list_export
      return enum_for(:user_list_export) unless block_given?

      user_field_ids = UserField.pluck(:id)

      condition = {}
      if @extra && @extra[:trust_level] && trust_level = TrustLevel.levels[@extra[:trust_level].to_sym]
        condition = { trust_level: trust_level }
      end

      if SiteSetting.enable_sso
        # SSO enabled
        User.where(condition).includes(:user_profile, :user_stat, :user_emails, :single_sign_on_record, :groups).find_each do |user|
          user_info_array = get_base_user_array(user)
          user_info_array = add_single_sign_on(user, user_info_array)
          user_info_array = add_custom_fields(user, user_info_array, user_field_ids)
          user_info_array = add_group_names(user, user_info_array)
          yield user_info_array
        end
      else
        # SSO disabled
        User.where(condition).includes(:user_profile, :user_stat, :user_emails, :groups).find_each do |user|
          user_info_array = get_base_user_array(user)
          user_info_array = add_custom_fields(user, user_info_array, user_field_ids)
          user_info_array = add_group_names(user, user_info_array)
          yield user_info_array
        end
      end
    end

    def staff_action_export
      return enum_for(:staff_action_export) unless block_given?

      staff_action_data = if @current_user.admin?
        UserHistory.only_staff_actions.order('id DESC')
      else
        UserHistory.where(admin_only: false).only_staff_actions.order('id DESC')
      end

      staff_action_data.each do |staff_action|
        yield get_staff_action_fields(staff_action)
      end
    end

    def screened_email_export
      return enum_for(:screened_email_export) unless block_given?

      ScreenedEmail.order('last_match_at DESC').each do |screened_email|
        yield get_screened_email_fields(screened_email)
      end
    end

    def screened_ip_export
      return enum_for(:screened_ip_export) unless block_given?

      ScreenedIpAddress.order('id DESC').each do |screened_ip|
        yield get_screened_ip_fields(screened_ip)
      end
    end

    def screened_url_export
      return enum_for(:screened_url_export) unless block_given?

      ScreenedUrl.select("domain, sum(match_count) as match_count, max(last_match_at) as last_match_at, min(created_at) as created_at")
        .group(:domain)
        .order('last_match_at DESC')
        .each do |screened_url|
        yield get_screened_url_fields(screened_url)
      end
    end

    def report_export
      return enum_for(:report_export) unless block_given?

      @extra[:start_date] = @extra[:start_date].to_date.beginning_of_day if @extra[:start_date].is_a?(String)
      @extra[:end_date] = @extra[:end_date].to_date.end_of_day if @extra[:end_date].is_a?(String)
      @extra[:category_id] = @extra[:category_id].present? ? @extra[:category_id].to_i : nil
      @extra[:group_id] = @extra[:group_id].present? ? @extra[:group_id].to_i : nil

      report = Report.find(@extra[:name], @extra)

      header = []
      titles = {}

      report.labels.each do |label|
        if label[:type] == :user
          titles[label[:properties][:username]] = label[:title]
          header << label[:properties][:username]
        else
          titles[label[:property]] = label[:title]
          header << label[:property]
        end
      end

      if report.modes == [:stacked_chart]
        header = [:x]
        data = {}

        report.data.map do |series|
          header << series[:label]
          series[:data].each do |datapoint|
            data[datapoint[:x]] ||= { x: datapoint[:x] }
            data[datapoint[:x]][series[:label]] = datapoint[:y]
          end
        end

        data = data.values
      else
        data = report.data
      end

      yield header.map { |k| titles[k] || k }
      data.each { |row| yield row.values_at(*header).map(&:to_s) }
    end

    def get_header
      if @entity == 'user_list'
        header_array = HEADER_ATTRS_FOR['user_list'] + HEADER_ATTRS_FOR['user_stats'] + HEADER_ATTRS_FOR['user_profile']
        header_array.concat(HEADER_ATTRS_FOR['user_sso']) if SiteSetting.enable_sso
        user_custom_fields = UserField.all
        if user_custom_fields.present?
          user_custom_fields.each do |custom_field|
            header_array.push("#{custom_field.name} (custom user field)")
          end
        end
        header_array.push("group_names")
      else
        header_array = HEADER_ATTRS_FOR[@entity]
      end

      header_array
    end

    private

    def escape_comma(string)
      string&.include?(",") ? %Q|"#{string}"| : string
    end

    def get_base_user_array(user)
      [
        user.id,
        escape_comma(user.name),
        user.username,
        user.email,
        escape_comma(user.title),
        user.created_at,
        user.last_seen_at,
        user.last_posted_at,
        user.last_emailed_at,
        user.trust_level,
        user.approved,
        user.suspended_at,
        user.suspended_till,
        user.silenced_till,
        user.active,
        user.admin,
        user.moderator,
        user.ip_address,
        user.staged,
        user.secondary_emails.join(";"),
        user.user_stat.topics_entered,
        user.user_stat.posts_read_count,
        user.user_stat.time_read,
        user.user_stat.topic_count,
        user.user_stat.post_count,
        user.user_stat.likes_given,
        user.user_stat.likes_received,
        escape_comma(user.user_profile.location),
        user.user_profile.website,
        user.user_profile.views,
      ]
    end

    def add_single_sign_on(user, user_info_array)
      if user.single_sign_on_record
        user_info_array.push(user.single_sign_on_record.external_id, user.single_sign_on_record.external_email, user.single_sign_on_record.external_username, escape_comma(user.single_sign_on_record.external_name), user.single_sign_on_record.external_avatar_url)
      else
        user_info_array.push(nil, nil, nil, nil, nil)
      end
      user_info_array
    end

    def add_custom_fields(user, user_info_array, user_field_ids)
      if user_field_ids.present?
        user.user_fields.each do |custom_field|
          user_info_array << escape_comma(custom_field[1])
        end
      end
      user_info_array
    end

    def add_group_names(user, user_info_array)
      group_names = user.groups.map { |g| g.name }.join(";")
      user_info_array << escape_comma(group_names) if group_names.present?
      user_info_array
    end

    def get_user_archive_fields(user_archive)
      user_archive_array = []
      topic_data = user_archive.topic
      user_archive = user_archive.as_json
      topic_data = Topic.with_deleted.find_by(id: user_archive['topic_id']) if topic_data.nil?
      return user_archive_array if topic_data.nil?

      all_categories = Category.all.to_h { |category| [category.id, category] }

      categories = "-"
      if topic_data.category_id && category = all_categories[topic_data.category_id]
        categories = [category.name]
        while category.parent_category_id && category = all_categories[category.parent_category_id]
          categories << category.name
        end
        categories = categories.reverse.join("|")
      end

      is_pm = topic_data.archetype == "private_message" ? I18n.t("csv_export.boolean_yes") : I18n.t("csv_export.boolean_no")
      url = "#{Discourse.base_url}/t/#{topic_data.slug}/#{topic_data.id}/#{user_archive['post_number']}"

      topic_hash = { "post" => user_archive['raw'], "topic_title" => topic_data.title, "categories" => categories, "is_pm" => is_pm, "url" => url }
      user_archive.merge!(topic_hash)

      HEADER_ATTRS_FOR['user_archive'].each do |attr|
        user_archive_array.push(user_archive[attr])
      end

      user_archive_array
    end

    def get_staff_action_fields(staff_action)
      staff_action_array = []

      HEADER_ATTRS_FOR['staff_action'].each do |attr|
        data =
          if attr == 'action'
            UserHistory.actions.key(staff_action.attributes[attr]).to_s
          elsif attr == 'staff_user'
            user = User.find_by(id: staff_action.attributes['acting_user_id'])
            user.username if !user.nil?
          elsif attr == 'subject'
            user = User.find_by(id: staff_action.attributes['target_user_id'])
            user.nil? ? staff_action.attributes[attr] : "#{user.username} #{staff_action.attributes[attr]}"
          else
            staff_action.attributes[attr]
          end

          staff_action_array.push(data)
      end
      staff_action_array
    end

    def get_screened_email_fields(screened_email)
      screened_email_array = []

      HEADER_ATTRS_FOR['screened_email'].each do |attr|
        data =
          if attr == 'action'
            ScreenedEmail.actions.key(screened_email.attributes['action_type']).to_s
          else
            screened_email.attributes[attr]
          end

        screened_email_array.push(data)
      end

      screened_email_array
    end

    def get_screened_ip_fields(screened_ip)
      screened_ip_array = []

      HEADER_ATTRS_FOR['screened_ip'].each do |attr|
        data =
          if attr == 'action'
            ScreenedIpAddress.actions.key(screened_ip.attributes['action_type']).to_s
          else
            screened_ip.attributes[attr]
          end

        screened_ip_array.push(data)
      end

      screened_ip_array
    end

    def get_screened_url_fields(screened_url)
      screened_url_array = []

      HEADER_ATTRS_FOR['screened_url'].each do |attr|
        data =
          if attr == 'action'
            action = ScreenedUrl.actions.key(screened_url.attributes['action_type']).to_s
            action = "do nothing" if action.blank?
          else
            screened_url.attributes[attr]
          end

        screened_url_array.push(data)
      end

      screened_url_array
    end

    def notify_user(upload, export_title)
      post = nil

      if @current_user
        post = if upload
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
