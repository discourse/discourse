require 'csv'
require_dependency 'system_message'

module Jobs

  class BulkInvite < Jobs::Base
    sidekiq_options retry: false

    def initialize
      super
      @logs    = []
      @sent    = 0
      @failed  = 0
    end

    def execute(args)
      filename = args[:filename]
      raise Discourse::InvalidParameters.new(:filename) if filename.blank?

      @current_user = User.find_by(id: args[:current_user_id])
      raise Discourse::InvalidParameters.new(:current_user_id) unless @current_user

      csv_path = "#{Invite.base_directory}/#{filename}"

      # read csv file, and send out invitations
      read_csv_file(csv_path)
    ensure
      # send notification to user regarding progress
      notify_user

      FileUtils.rm_rf(csv_path) if csv_path
    end

    private

    def read_csv_file(csv_path)
      file = File.open(csv_path, encoding: 'bom|utf-8')
      CSV.new(file).each do |csv_info|
        if csv_info[0]
          if (EmailValidator.email_regex =~ csv_info[0])
            # email is valid
            send_invite(csv_info, $INPUT_LINE_NUMBER)
            @sent += 1
          else
            # invalid email
            save_log "Invalid Email '#{csv_info[0]}' at line number '#{$INPUT_LINE_NUMBER}'"
            @failed += 1
          end
        end
      end
    rescue Exception => e
      save_log "Bulk Invite Process Failed -- '#{e.message}'"
      @failed += 1
    ensure
      file&.close
    end

    def get_groups(group_names, csv_line_number)
      groups = []

      if group_names
        group_names = group_names.split(';')
        guardian = Guardian.new(@current_user)

        group_names.each { |group_name|
          group_detail = Group.find_by_name(group_name)

          if group_detail && guardian.can_edit_group?(group_detail)
            # valid group
            groups.push(group_detail)
          else
            # invalid group
            save_log "Invalid Group '#{group_name}' at line number '#{csv_line_number}'"
            @failed += 1
          end
        }
      end

      groups
    end

    def get_topic(topic_id, csv_line_number)
      topic = nil

      if topic_id
        topic = Topic.find_by_id(topic_id)
        if topic.nil?
          save_log "Invalid Topic ID '#{topic_id}' at line number '#{csv_line_number}'"
          @failed += 1
        end
      end

      return topic
    end

    def send_invite(csv_info, csv_line_number)
      email = csv_info[0]
      groups = get_groups(csv_info[1], csv_line_number)
      topic = get_topic(csv_info[2], csv_line_number)

      begin
        if user = User.find_by_email(email)
          if groups.present?
            Group.transaction do
              groups.each do |group|
                group.add(user)

                GroupActionLogger
                  .new(@current_user, group)
                  .log_add_user_to_group(user)
              end
            end
          end
        else
          Invite.invite_by_email(email, @current_user, topic, groups.map(&:id))
        end
      rescue => e
        save_log "Error inviting '#{email}' -- #{Rails::Html::FullSanitizer.new.sanitize(e.message)}"
        @sent -= 1
        @failed += 1
      end
    end

    def save_log(message)
      @logs << "[#{Time.now}] #{message}"
    end

    def notify_user
      if @current_user
        if (@sent > 0 && @failed == 0)
          SystemMessage.create_from_system_user(
            @current_user,
            :bulk_invite_succeeded,
            sent: @sent
          )
        else
          SystemMessage.create_from_system_user(
            @current_user,
            :bulk_invite_failed,
            sent: @sent,
            failed: @failed,
            logs: @logs.join("\n")
          )
        end
      end
    end

  end

end
