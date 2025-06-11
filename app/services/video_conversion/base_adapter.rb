# frozen_string_literal: true
module VideoConversion
  class BaseAdapter
    def initialize(upload, options = {})
      @upload = upload
      @options = options
    end

    # Starts the conversion process and returns a job identifier
    def convert
      raise NotImplementedError, "#{self.class} must implement #convert"
    end

    # Checks the status of a conversion job
    # Returns a symbol: :complete, :error, :pending
    def check_status(job_id)
      raise NotImplementedError, "#{self.class} must implement #check_status"
    end

    # Handles the completion of a successful conversion
    # This is called by the job system when status is :complete
    def handle_completion(job_id, output_path, new_sha1)
      raise NotImplementedError, "#{self.class} must implement #handle_completion"
    end

    protected

    def create_optimized_video_record(output_path, new_sha1, filesize, url)
      OptimizedVideo.create_for(
        @upload,
        @upload.original_filename.sub(/\.[^.]+$/, "_converted.mp4"),
        @upload.user_id,
        filesize: filesize,
        sha1: new_sha1,
        url: url,
        extension: "mp4",
      )
    end
  end
end
