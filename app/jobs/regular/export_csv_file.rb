# frozen_string_literal: true

require "csv"

module Jobs
  class ExportCsvFile < ::Jobs::Base
    sidekiq_options retry: false

    attr_accessor :extra
    attr_accessor :current_user
    attr_accessor :entity

    HEADER_ATTRS_FOR ||=
      HashWithIndifferentAccess.new(
        user_list: %w[
          id
          name
          username
          email
          title
          created_at
          last_seen_at
          last_posted_at
          last_emailed_at
          trust_level
          approved
          suspended_at
          suspended_till
          silenced_till
          active
          admin
          moderator
          ip_address
          staged
          secondary_emails
        ],
        user_stats: %w[
          topics_entered
          posts_read_count
          time_read
          topic_count
          post_count
          likes_given
          likes_received
        ],
        user_profile: %w[location website views],
        user_sso: %w[
          external_id
          external_email
          external_username
          external_name
          external_avatar_url
        ],
        staff_action: %w[staff_user action subject created_at details context],
        screened_email: %w[email action match_count last_match_at created_at ip_address],
        screened_ip: %w[ip_address action match_count last_match_at created_at],
        screened_url: %w[domain action match_count last_match_at created_at],
        report: %w[date value],
      )

    def execute(args)
      @entity = args[:entity]
      @extra = HashWithIndifferentAccess.new(args[:args]) if args[:args]
      @current_user = User.find_by(id: args[:user_id])

      entities = [{ name: @entity }]

      entities.each do |entity|
        entity[:method] = :"#{entity[:name]}_export"
        raise Discourse::InvalidParameters.new(:entity) unless respond_to?(entity[:method])

        @timestamp ||= Time.now.strftime("%y%m%d-%H%M%S")
        entity[:filename] = if entity[:name] == "report" && @extra[:name].present?
          "#{@extra[:name].dasherize}-#{@timestamp}"
        else
          "#{entity[:name].dasherize}-#{@timestamp}"
        end
      end

      export_title =
        if @entity == "report" && @extra[:name].present?
          I18n.t("reports.#{@extra[:name]}.title")
        else
          @entity.gsub("_", " ").titleize
        end

      filename = entities[0][:filename] # use first entity as a name for this export
      user_export = UserExport.create(file_name: filename, user_id: @current_user.id)
      filename = "#{filename}-#{user_export.id}"

      zip_filename = write_to_csv_and_zip(filename, entities)

      # create upload
      upload = nil

      if File.exist?(zip_filename)
        File.open(zip_filename) do |file|
          upload =
            UploadCreator.new(
              file,
              File.basename(zip_filename),
              type: "csv_export",
              for_export: "true",
            ).create_for(@current_user.id)

          if upload.persisted?
            user_export.update_columns(upload_id: upload.id)
          else
            Rails.logger.warn("Failed to upload the file #{zip_filename}")
          end
        end

        File.delete(zip_filename)
      end
    ensure
      post = notify_user(upload, export_title)

      if user_export.present? && post.present?
        topic = post.topic
        user_export.update_columns(topic_id: topic.id)
        topic.update_status("closed", true, Discourse.system_user)
      end
    end

    def user_list_export
      return enum_for(:user_list_export) unless block_given?

      user_field_ids = UserField.pluck(:id)

      condition = {}
      if @extra && @extra[:trust_level] &&
           trust_level = TrustLevel.levels[@extra[:trust_level].to_sym]
        condition = { trust_level: trust_level }
      end

      includes = %i[user_profile user_stat groups user_emails]
      includes << [:single_sign_on_record] if SiteSetting.enable_discourse_connect

      User
        .where(condition)
        .includes(*includes)
        .find_each do |user|
          user_info_array = get_base_user_array(user)
          if SiteSetting.enable_discourse_connect
            user_info_array = add_single_sign_on(user, user_info_array)
          end
          user_info_array = add_custom_fields(user, user_info_array, user_field_ids)
          user_info_array = add_group_names(user, user_info_array)
          yield user_info_array
        end
    end

    def staff_action_export
      return enum_for(:staff_action_export) unless block_given?

      staff_action_data =
        if @current_user.admin?
          UserHistory.only_staff_actions
        else
          UserHistory.where(admin_only: false).only_staff_actions
        end

      staff_action_data.find_each(order: :desc) do |staff_action|
        yield get_staff_action_fields(staff_action)
      end
    end

    def screened_email_export
      return enum_for(:screened_email_export) unless block_given?

      ScreenedEmail.find_each(order: :desc) do |screened_email|
        yield get_screened_email_fields(screened_email)
      end
    end

    def screened_ip_export
      return enum_for(:screened_ip_export) unless block_given?

      ScreenedIpAddress.find_each(order: :desc) do |screened_ip|
        yield get_screened_ip_fields(screened_ip)
      end
    end

    def screened_url_export
      return enum_for(:screened_url_export) unless block_given?

      ScreenedUrl
        .select(
          "domain, sum(match_count) as match_count, max(last_match_at) as last_match_at, min(created_at) as created_at",
        )
        .group(:domain)
        .order("last_match_at DESC")
        .each { |screened_url| yield get_screened_url_fields(screened_url) }
    end

    def report_export
      return enum_for(:report_export) unless block_given?

      # If dates are invalid consider then `nil`
      if @extra[:start_date].is_a?(String)
        @extra[:start_date] = begin
          @extra[:start_date].to_date.beginning_of_day
        rescue StandardError
          nil
        end
      end
      if @extra[:end_date].is_a?(String)
        @extra[:end_date] = begin
          @extra[:end_date].to_date.end_of_day
        rescue StandardError
          nil
        end
      end

      @extra[:filters] = {}
      @extra[:filters][:category] = @extra[:category].to_i if @extra[:category].present?
      @extra[:filters][:group] = @extra[:group].to_i if @extra[:group].present?
      @extra[:filters][:include_subcategories] = !!ActiveRecord::Type::Boolean.new.cast(
        @extra[:include_subcategories],
      ) if @extra[:include_subcategories].present?

      report = Report.find(@extra[:name], @extra)

      header = []
      titles = {}

      report.labels.each do |label|
        if label[:type] == :user
          titles[label[:properties][:username]] = label[:title]
          header << label[:properties][:username]
        elsif label[:type] == :topic
          titles[label[:properties][:id]] = label[:title]
          header << label[:properties][:id]
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

    def get_header(entity)
      if entity == "user_list"
        header_array =
          HEADER_ATTRS_FOR["user_list"] + HEADER_ATTRS_FOR["user_stats"] +
            HEADER_ATTRS_FOR["user_profile"]
        header_array.concat(HEADER_ATTRS_FOR["user_sso"]) if SiteSetting.enable_discourse_connect
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

    def escape_comma(string)
      string&.include?(",") ? %Q|"#{string}"| : string
    end

    def get_base_user_array(user)
      # preloading scopes is hard, do this by hand
      secondary_emails = []
      primary_email = nil

      user.user_emails.each do |user_email|
        if user_email.primary?
          primary_email = user_email.email
        else
          secondary_emails << user_email.email
        end
      end

      [
        user.id,
        escape_comma(user.name),
        user.username,
        primary_email,
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
        secondary_emails.join(";"),
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
        user_info_array.push(
          user.single_sign_on_record.external_id,
          user.single_sign_on_record.external_email,
          user.single_sign_on_record.external_username,
          escape_comma(user.single_sign_on_record.external_name),
          user.single_sign_on_record.external_avatar_url,
        )
      else
        user_info_array.push(nil, nil, nil, nil, nil)
      end
      user_info_array
    end

    def add_custom_fields(user, user_info_array, user_field_ids)
      if user_field_ids.present?
        user.user_fields.each { |custom_field| user_info_array << escape_comma(custom_field[1]) }
      end
      user_info_array
    end

    def add_group_names(user, user_info_array)
      group_names = user.groups.map { |g| g.name }.join(";")
      if group_names.present?
        user_info_array << escape_comma(group_names)
      else
        user_info_array << nil
      end
      user_info_array
    end

    def get_staff_action_fields(staff_action)
      staff_action_array = []

      HEADER_ATTRS_FOR["staff_action"].each do |attr|
        data =
          if attr == "action"
            UserHistory.actions.key(staff_action.attributes[attr]).to_s
          elsif attr == "staff_user"
            user = User.find_by(id: staff_action.attributes["acting_user_id"])
            user.username if !user.nil?
          elsif attr == "subject"
            user = User.find_by(id: staff_action.attributes["target_user_id"])
            if user.nil?
              staff_action.attributes[attr]
            else
              "#{user.username} #{staff_action.attributes[attr]}"
            end
          else
            staff_action.attributes[attr]
          end

        staff_action_array.push(data)
      end
      staff_action_array
    end

    def get_screened_email_fields(screened_email)
      screened_email_array = []

      HEADER_ATTRS_FOR["screened_email"].each do |attr|
        data =
          if attr == "action"
            ScreenedEmail.actions.key(screened_email.attributes["action_type"]).to_s
          else
            screened_email.attributes[attr]
          end

        screened_email_array.push(data)
      end

      screened_email_array
    end

    def get_screened_ip_fields(screened_ip)
      screened_ip_array = []

      HEADER_ATTRS_FOR["screened_ip"].each do |attr|
        data =
          if attr == "action"
            ScreenedIpAddress.actions.key(screened_ip.attributes["action_type"]).to_s
          else
            screened_ip.attributes[attr]
          end

        screened_ip_array.push(data)
      end

      screened_ip_array
    end

    def get_screened_url_fields(screened_url)
      screened_url_array = []

      HEADER_ATTRS_FOR["screened_url"].each do |attr|
        data =
          if attr == "action"
            action = ScreenedUrl.actions.key(screened_url.attributes["action_type"]).to_s
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
        post =
          if upload
            SystemMessage.create_from_system_user(
              @current_user,
              :csv_export_succeeded,
              download_link: UploadMarkdown.new(upload).attachment_markdown,
              export_title: export_title,
            )
          else
            SystemMessage.create_from_system_user(@current_user, :csv_export_failed)
          end
      end

      post
    end

    def write_to_csv_and_zip(filename, entities)
      dirname = "#{UserExport.base_directory}/#{filename}"
      FileUtils.mkdir_p(dirname) unless Dir.exist?(dirname)
      begin
        entities.each do |entity|
          CSV.open("#{dirname}/#{entity[:filename]}.csv", "w") do |csv|
            csv << get_header(entity[:name]) if entity[:name] != "report"
            public_send(entity[:method]) { |d| csv << d }
          end
        end

        Compression::Zip.new.compress(UserExport.base_directory, filename)
      ensure
        FileUtils.rm_rf(dirname)
      end
    end
  end
end
