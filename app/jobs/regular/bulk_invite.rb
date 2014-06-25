require 'csv'
require_dependency 'system_message'

module Jobs

  class BulkInvite < Jobs::Base
    sidekiq_options retry: false

    def initialize
      @logs    = []
      @sent    = 0
      @failed  = 0
    end

    def execute(args)
      filename     = args[:filename]
      identifier   = args[:identifier]
      chunks       = args[:chunks].to_i
      current_user = User.find_by(id: args[:current_user_id])

      raise Discourse::InvalidParameters.new(:filename)   if filename.blank?
      raise Discourse::InvalidParameters.new(:identifier) if identifier.blank?
      raise Discourse::InvalidParameters.new(:chunks)     if chunks <= 0

      # merge chunks, and get csv path
      csv_path = get_csv_path(filename, identifier, chunks)

      # read csv file, and send out invitations
      read_csv_file(csv_path, current_user)

      # send notification to user regarding progress
      notify_user(current_user)

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

    def read_csv_file(csv_path, current_user)
      CSV.foreach(csv_path) do |csv_info|
        if !csv_info[0].nil?
          if validate_email(csv_info[0])
            # email is valid, now check for groups
            if !csv_info[1].nil?
              # group(s) present
              send_invite_with_groups(csv_info[0], csv_info[1], current_user, $INPUT_LINE_NUMBER)
            else
              # no group present
              send_invite_without_group(csv_info[0], current_user)
            end
            @sent += 1
          else
            # invalid email
            log "Invalid email '#{csv_info[0]}' at line number '#{$INPUT_LINE_NUMBER}'"
            @failed += 1
          end
        end
      end
    end

    def validate_email(email)
      /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/.match(email)
    end

    def send_invite_with_groups(email, group_names, current_user, csv_line_number)
      group_ids = []
      group_names = group_names.split(';')
      group_names.each { |group_name|
        group_detail = Group.find_by_name(group_name)
        if !group_detail.nil?
          # valid group
          group_ids.push(group_detail.id)
        else
          # invalid group
          log "Invalid group '#{group_name}' at line number '#{csv_line_number}'"
        end
      }
      Invite.invite_by_email(email, current_user, topic=nil, group_ids)
    end

    def send_invite_without_group(email, current_user)
      Invite.invite_by_email(email, current_user, topic=nil)
    end

    def log(message)
      puts(message) rescue nil
      save_log(message)
    end

    def save_log(message)
      @logs << "[#{Time.now}] #{message}"
    end

    def notify_user(current_user)
      if current_user
        if (@sent > 0 && @failed == 0)
          SystemMessage.create(current_user, :bulk_invite_succeeded, sent: @sent)
        else
          SystemMessage.create(current_user, :bulk_invite_failed, sent: @sent, failed: @failed, logs: @logs.join("\n"))
        end
      end
    end

  end

end
