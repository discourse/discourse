# frozen_string_literal: true
module VideoConversion
  class BaseAdapter
    STATUS_COMPLETE = :complete
    STATUS_ERROR = :error
    STATUS_PENDING = :pending

    def initialize(upload, options = {})
      @upload = upload
      @options = options
    end

    # Starts the conversion process and returns a job identifier
    def convert
      raise NotImplementedError, "#{self.class} must implement #convert"
    end

    # Checks the status of a conversion job
    # Returns a symbol: STATUS_COMPLETE, STATUS_ERROR, or STATUS_PENDING
    def check_status(job_id)
      raise NotImplementedError, "#{self.class} must implement #check_status"
    end

    # Handles the completion of a successful conversion
    # This is called by the job system when status is :complete
    def handle_completion(job_id, new_sha1)
      raise NotImplementedError, "#{self.class} must implement #handle_completion"
    end

    protected

    def create_optimized_video_record(output_path, new_sha1, filesize, url, etag: nil)
      options = {
        filesize: filesize,
        sha1: new_sha1,
        url: url,
        extension: "mp4",
        adapter: adapter_name,
      }
      options[:etag] = etag if etag.present?

      OptimizedVideo.create_for(
        @upload,
        @upload.original_filename.sub(/\.[^.]+$/, "_converted.mp4"),
        @upload.user_id,
        **options,
      )
    end

    def update_posts_with_optimized_video(optimized_video)
      Post
        .where(
          id: UploadReference.where(upload_id: @upload.id, target_type: "Post").select(:target_id),
        )
        .find_each do |post|
          Rails.logger.info("Rebaking post #{post.id} to use optimized video")
          post.rebake!
        end

      chat_message_subquery =
        UploadReference.where(upload_id: @upload.id, target_type: "ChatMessage").select(:target_id)

      if chat_message_subquery.exists? && defined?(Chat::Message)
        Chat::Message
          .where(id: chat_message_subquery)
          .includes(uploads: { optimized_videos: :optimized_upload })
          .find_each do |chat_message|
            Rails.logger.info(
              "Rebaking chat message #{chat_message.id} to use optimized video (upload_id: #{@upload.id}, optimized_upload_id: #{optimized_video.optimized_upload.id})",
            )
            chat_message.rebake!
          end
      end
    end

    private

    def adapter_name
      self.class::ADAPTER_NAME
    rescue NameError
      # Fallback for adapters that don't define ADAPTER_NAME
      self.class.name.demodulize.underscore
    end
  end
end
