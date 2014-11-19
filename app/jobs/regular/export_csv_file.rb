require 'csv'
require_dependency 'system_message'

module Jobs

  class ExportCsvFile < Jobs::Base
    CSV_USER_ATTRS = ['id','name','username','email','title','created_at','trust_level','active','admin','moderator','ip_address']
    CSV_USER_STATS = ['topics_entered','posts_read_count','time_read','topic_count','post_count','likes_given','likes_received']

    sidekiq_options retry: false
    attr_accessor :current_user

    def initialize
      @file_name = ""
    end

    def execute(args)
      entity = args[:entity]
      @current_user = User.find_by(id: args[:user_id])

      raise Discourse::InvalidParameters.new(:entity) if entity.blank?

      case entity
        when 'user'
          query = ::AdminUserIndexQuery.new
          user_data = query.find_users_query.to_a
          data = Array.new

          user_data.each do |user|
            user_array = Array.new
            group_names = get_group_names(user).join(';')
            user_array = get_user_fields(user)
            user_array.push(group_names) if group_names != ''
            data.push(user_array)
          end
      end

      if data && data.length > 0
        set_file_path
        write_csv_file(data)
      end

      notify_user
    end

    private

      def get_group_names(user)
        group_names = Array.new
        groups = user.groups
        groups.each do |group|
          group_names.push(group.name)
        end
        return group_names
      end

      def get_user_fields(user)
        user_array = Array.new

        CSV_USER_ATTRS.each do |attr|
          user_array.push(user.attributes[attr])
        end

        CSV_USER_STATS.each do |stat|
          user_array.push(user.user_stat.attributes[stat])
        end

        if user.user_fields.present?
          user.user_fields.each do |custom_field|
            user_array.push(custom_field[1])
          end
        end

        return user_array
      end

      def get_header
        header_array = CSV_USER_ATTRS + CSV_USER_STATS

        user_custom_fields = UserField.all
        if user_custom_fields.present?
          user_custom_fields.each do |custom_field|
            header_array.push("#{custom_field.name} (custom user field)")
          end
        end
        header_array.push("group_names")

        return header_array
      end

      def set_file_path
        @file_name = "export_#{SecureRandom.hex(4)}.csv"
        # ensure directory exists
        dir = File.dirname("#{ExportCsv.base_directory}/#{@file_name}")
        FileUtils.mkdir_p(dir) unless Dir.exists?(dir)
      end

      def write_csv_file(data)
        # write to CSV file
        CSV.open(File.expand_path("#{ExportCsv.base_directory}/#{@file_name}", __FILE__), "w") do |csv|
          csv << get_header
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
