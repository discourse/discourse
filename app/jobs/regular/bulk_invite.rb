require 'csv'
require_dependency 'system_message'

module Jobs

  class BulkInvite < Jobs::Base
    sidekiq_options retry: false
    attr_accessor :current_user

    def initialize
      @logs    = []
      @sent    = 0
      @failed  = 0
    end

    def execute(args)
      filename     = args[:filename]
      identifier   = args[:identifier]
      chunks       = args[:chunks].to_i
      @current_user = User.find_by(id: args[:current_user_id])

      raise Discourse::InvalidParameters.new(:filename)   if filename.blank?
      raise Discourse::InvalidParameters.new(:identifier) if identifier.blank?
      raise Discourse::InvalidParameters.new(:chunks)     if chunks <= 0

      # merge chunks, and get csv path
      csv_path = get_csv_path(filename, identifier, chunks)

      # read csv file, and send out invitations
      read_csv_file(csv_path)

      # send notification to user regarding progress
      notify_user

      # since emails have already been sent out, delete the uploaded csv file
      FileUtils.rm_rf(csv_path) rescue nil
    end

    def get_csv_path(filename, identifier, chunks)
      csv_path = "#{Invite.base_directory}/#{filename}"
      tmp_csv_path = "#{csv_path}.tmp"
      # path to tmp directory
      tmp_directory = File.dirname(Invite.chunk_path(identifier, filename, 0))
      # merge all chunks
      HandleChunkUpload.merge_chunks(chunks, upload_path: csv_path, tmp_upload_path: tmp_csv_path, model: Invite, identifier: identifier, filename: filename, tmp_directory: tmp_directory)

      return csv_path
    end

    def read_csv_file(csv_path)
      CSV.foreach(csv_path) do |csv_info|
        if csv_info[0]
          if (EmailValidator.email_regex =~ csv_info[0])
            # email is valid
            send_invite(csv_info, $INPUT_LINE_NUMBER)
            @sent += 1
          else
            # invalid email
            log "Invalid Email '#{csv_info[0]}' at line number '#{$INPUT_LINE_NUMBER}'"
            @failed += 1
          end
        end
      end
    end

    def get_group_ids(group_names, csv_line_number)
      group_ids = []
      if group_names
        group_names = group_names.split(';')
        group_names.each { |group_name|
          group_detail = Group.find_by_name(group_name)
          if group_detail
            # valid group
            group_ids.push(group_detail.id)
          else
            # invalid group
            log "Invalid Group '#{group_name}' at line number '#{csv_line_number}'"
            @failed += 1
          end
        }
      end
      return group_ids
    end

    def get_topic(topic_id, csv_line_number)
      topic = nil
      if topic_id
        topic = Topic.find_by_id(topic_id)
        if topic.nil?
          log "Invalid Topic ID '#{topic_id}' at line number '#{csv_line_number}'"
          @failed += 1
        end
      end
      return topic
    end

    def send_invite(csv_info, csv_line_number)
      email = csv_info[0]
      group_ids = get_group_ids(csv_info[1], csv_line_number)
      topic = get_topic(csv_info[2], csv_line_number)
      begin
        Invite.invite_by_email(email, @current_user, topic, group_ids)
      rescue => e
        log "Error inviting '#{email}' -- #{e}"
        @sent -= 1
        @failed += 1
      end
    end

    def log(message)
      save_log(message)
    end

    def save_log(message)
      @logs << "[#{Time.now}] #{message}"
    end

    def notify_user
      if @current_user
        if (@sent > 0 && @failed == 0)
          SystemMessage.create_from_system_user(@current_user, :bulk_invite_succeeded, sent: @sent)
        else
          SystemMessage.create_from_system_user(@current_user, :bulk_invite_failed, sent: @sent, failed: @failed, logs: @logs.join("\n"))
        end
      end
    end

  end

end
