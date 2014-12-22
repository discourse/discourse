require 'csv'
require_dependency 'system_message'

module Jobs

  class ExportCsvFile < Jobs::Base
    HEADER_ATTRS_FOR = {}
    HEADER_ATTRS_FOR['user_archive'] = ['raw','like_count','reply_count','created_at']
    HEADER_ATTRS_FOR['user'] = ['id','name','username','email','title','created_at','trust_level','active','admin','moderator','ip_address']
    HEADER_ATTRS_FOR['user_stats'] = ['topics_entered','posts_read_count','time_read','topic_count','post_count','likes_given','likes_received']
    HEADER_ATTRS_FOR['user_sso'] = ['external_id','external_email', 'external_username', 'external_name', 'external_avatar_url']
    HEADER_ATTRS_FOR['staff_action'] = ['staff_user','action','subject','created_at','details', 'context']
    HEADER_ATTRS_FOR['screened_email'] = ['email','action','match_count','last_match_at','created_at','ip_address']
    HEADER_ATTRS_FOR['screened_ip'] = ['ip_address','action','match_count','last_match_at','created_at']
    HEADER_ATTRS_FOR['screened_url'] = ['domain','action','match_count','last_match_at','created_at']

    sidekiq_options retry: false
    attr_accessor :current_user

    def initialize
      @file_name = ""
      @entity_type = "admin"
    end

    def execute(args)
      entity = args[:entity]

      if entity == "user_archive"
        @entity_type = "user"
      end

      @current_user = User.find_by(id: args[:user_id])

      export_method = "#{entity}_export".to_sym
      data =
        if respond_to?(export_method)
          send(export_method)
        else
          raise Discourse::InvalidParameters.new(:entity)
        end

      if data && data.length > 0
        set_file_path
        header = get_header(entity)
        write_csv_file(data, header)
      end

      notify_user
    end

    def user_archive_export
      user_archive_data = Post.where(user_id: @current_user.id).select(HEADER_ATTRS_FOR['user_archive']).with_deleted.to_a
      user_archive_data.map do |user_archive|
        get_user_archive_fields(user_archive)
      end
    end

    def user_export
      query = ::AdminUserIndexQuery.new
      user_data = query.find_users_query.to_a
      user_data.map do |user|
        group_names = get_group_names(user).join(';')
        user_array = get_user_fields(user)
        user_array.push(group_names) if group_names != ''
        user_array
      end
    end

    def staff_action_export
      staff_action_data = UserHistory.order('id DESC').to_a
      staff_action_data.map do |staff_action|
        get_staff_action_fields(staff_action)
      end
    end

    def screened_email_export
      screened_email_data = ScreenedEmail.order('last_match_at desc').to_a
      screened_email_data.map do |screened_email|
        get_screened_email_fields(screened_email)
      end
    end

    def screened_ip_export
      screened_ip_data = ScreenedIpAddress.order('id desc').to_a
      screened_ip_data.map do |screened_ip|
        get_screened_ip_fields(screened_ip)
      end
    end

    def screened_url_export
      screened_url_data = ScreenedUrl.select("domain, sum(match_count) as match_count, max(last_match_at) as last_match_at, min(created_at) as created_at").group(:domain).order('last_match_at DESC').to_a
      screened_url_data.map do |screened_url|
        get_screened_url_fields(screened_url)
      end
    end

    def get_header(entity)

      case entity
        when 'user'
          header_array = HEADER_ATTRS_FOR['user'] + HEADER_ATTRS_FOR['user_stats']
          if SiteSetting.enable_sso
            header_array.concat(HEADER_ATTRS_FOR['user_sso'])
          end
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

      def get_group_names(user)
        group_names = []
        groups = user.groups
        groups.each do |group|
          group_names.push(group.name)
        end
        return group_names
      end

      def get_user_archive_fields(user_archive)
        user_archive_array = []

        HEADER_ATTRS_FOR['user_archive'].each do |attr|
          user_archive_array.push(user_archive.attributes[attr])
        end

        user_archive_array
      end

      def get_user_fields(user)
        user_array = []

        HEADER_ATTRS_FOR['user'].each do |attr|
          user_array.push(user.attributes[attr])
        end

        HEADER_ATTRS_FOR['user_stats'].each do |stat|
          user_array.push(user.user_stat.attributes[stat])
        end

        if SiteSetting.enable_sso
          sso = user.single_sign_on_record
          HEADER_ATTRS_FOR['user_sso'].each do |stat|
            field = sso.attributes[stat] if sso
            user_array.push(field)
          end
        end

        if user.user_fields.present?
          user.user_fields.each do |custom_field|
            user_array.push(custom_field[1])
          end
        end

        user_array
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


      def set_file_path
        @file_name = "export_#{SecureRandom.hex(4)}.csv"
        # ensure directory exists
        dir = File.dirname("#{ExportCsv.base_directory}/#{@file_name}")
        FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
      end

      def write_csv_file(data, header)
        # write to CSV file
        CSV.open(File.expand_path("#{ExportCsv.base_directory}/#{@file_name}", __FILE__), "w") do |csv|
          csv << header
          data.each do |value|
            csv << value
          end
        end
      end

      def notify_user
        if @current_user
          if @file_name != "" && File.exists?("#{ExportCsv.base_directory}/#{@file_name}")
            if @entity_type == "admin"
              SystemMessage.create_from_system_user(@current_user, :csv_export_succeeded, download_link: "#{Discourse.base_url}/export_csv/system/#{@file_name}", file_name: @file_name)
            else
              SystemMessage.create_from_system_user(@current_user, :csv_export_succeeded, download_link: "#{Discourse.base_url}/export_csv/#{@current_user.username}/#{@file_name}", file_name: @file_name)
            end
          else
            SystemMessage.create_from_system_user(@current_user, :csv_export_failed)
          end
        end
      end

  end

end
