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

      csv_path = "#{Invite.base_directory}/#{filename}"
      tmp_csv_path = "#{csv_path}.tmp"
      # path to tmp directory
      tmp_directory = File.dirname(Invite.chunk_path(identifier, filename, 0))

      # merge all chunks
      HandleChunkUpload.merge_chunks(chunks, upload_path: csv_path, tmp_upload_path: tmp_csv_path, model: Invite, identifier: identifier, filename: filename, tmp_directory: tmp_directory)

      # read csv file, and send out invitations
      CSV.foreach(csv_path) do |csv_info|
        if !csv_info[0].nil?
          if validate_email(csv_info[0])
            Invite.invite_by_email(csv_info[0], current_user, topic=nil)
            @sent += 1
          else
            log "Invalid email '#{csv_info[0]}' at line number '#{$INPUT_LINE_NUMBER}'"
            @failed += 1
          end
        end
      end

      # send notification to user regarding progress
      notify_user(current_user)

      # since emails have already been sent out, delete the uploaded csv file
      FileUtils.rm_rf(csv_path) rescue nil
    end

    def validate_email(email)
      /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/.match(email)
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
