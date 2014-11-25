require 'csv'
require_dependency 'system_message'

module Jobs

  class ExportCsvFile < Jobs::Base
    CSV_USER_ATTRS = ['id','name','username','email','title','created_at','trust_level','active','admin','moderator','ip_address']
    CSV_USER_STATS = ['topics_entered','posts_read_count','time_read','topic_count','post_count','likes_given','likes_received']
    CSV_USER_SSO_ATTRS = ['external_id','external_email', 'external_username', 'external_name', 'external_avatar_url']
    SCREENED_IP_ATTRS = ['ip_address','action_type','match_count','last_match_at','created_at']

    sidekiq_options retry: false
    attr_accessor :current_user

    def initialize
      @file_name = ""
    end

    def execute(args)
      entity = args[:entity]
      @current_user = User.find_by(id: args[:user_id])


      data =
        if entity == 'user'
          user_export
        elsif entity == 'screened_ips'
          screened_ips_export
        else
          raise Discourse::InvalidParameters.new(:entity) if entity.blank?
        end

      if data && data.length > 0
        set_file_path
        header = get_header(entity)
        write_csv_file(data, header)
      end

      notify_user
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


    def screened_ips_export
      screened_ips_data = ScreenedIpAddress.order('id desc').to_a
      screened_ips_data.map do |screened_ip|
        get_screened_ip_fields(screened_ip)
      end
    end

    def get_header(entity)

      case entity
        when 'user'
          header_array = CSV_USER_ATTRS + CSV_USER_STATS
          if SiteSetting.enable_sso
            header_array.concat(CSV_USER_SSO_ATTRS)
          end
          user_custom_fields = UserField.all
          if user_custom_fields.present?
            user_custom_fields.each do |custom_field|
              header_array.push("#{custom_field.name} (custom user field)")
            end
          end
          header_array.push("group_names")
        when 'screened_ips'
          header_array = SCREENED_IP_ATTRS
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

      def get_user_fields(user)
        user_array = []

        CSV_USER_ATTRS.each do |attr|
          user_array.push(user.attributes[attr])
        end

        CSV_USER_STATS.each do |stat|
          user_array.push(user.user_stat.attributes[stat])
        end

        if SiteSetting.enable_sso
          sso = user.single_sign_on_record
          CSV_USER_SSO_ATTRS.each do |stat|
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

      def get_screened_ip_fields(screened_ip)
        screened_ip_array = []

        SCREENED_IP_ATTRS.each do |attr|
          screened_ip_array.push(screened_ip.attributes[attr])
        end

        screened_ip_array
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
            SystemMessage.create_from_system_user(@current_user, :csv_export_succeeded, download_link: "#{Discourse.base_url}/admin/export_csv/#{@file_name}", file_name: @file_name)
          else
            SystemMessage.create_from_system_user(@current_user, :csv_export_failed)
          end
        end
      end

  end

end
