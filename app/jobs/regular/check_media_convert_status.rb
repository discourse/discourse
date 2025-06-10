# frozen_string_literal: true

require "aws-sdk-mediaconvert"
require "file_store/s3_store"
require "upload_creator"

module Jobs
  class CheckMediaConvertStatus < ::Jobs::Base
    sidekiq_options queue: "low", concurrency: 5

    def execute(args)
      return unless SiteSetting.mediaconvert_enabled
      upload_id = args[:upload_id]
      job_id = args[:job_id]
      new_sha1 = args[:new_sha1]
      output_path = args[:output_path]
      original_filename = args[:original_filename]
      user_id = args[:user_id]

      return unless upload_id && job_id && new_sha1 && output_path && original_filename && user_id

      upload = Upload.find_by(id: upload_id)
      return unless upload

      begin
        if SiteSetting.mediaconvert_endpoint.blank?
          client =
            Aws::MediaConvert::Client.new(
              region: SiteSetting.s3_region,
              credentials:
                Aws::Credentials.new(
                  SiteSetting.s3_access_key_id,
                  SiteSetting.s3_secret_access_key,
                ),
            )

          resp = client.describe_endpoints
          SiteSetting.mediaconvert_endpoint = resp.endpoints[0].url
        end

        return if SiteSetting.mediaconvert_endpoint.blank?

        mediaconvert_client =
          Aws::MediaConvert::Client.new(
            region: SiteSetting.s3_region,
            credentials:
              Aws::Credentials.new(SiteSetting.s3_access_key_id, SiteSetting.s3_secret_access_key),
            endpoint: SiteSetting.mediaconvert_endpoint,
          )

        # Get job status
        response = mediaconvert_client.get_job(id: job_id)
        status = response.job.status

        case status
        when "COMPLETE"
          s3_store = FileStore::S3Store.new

          begin
            # MediaConvert always adds .mp4 to the output path
            path = "#{output_path}.mp4"
            object = s3_store.object_from_path(path)

            if object&.exists?
              begin
                # Set ACL to public-read for the optimized video, matching the pattern used for optimized images
                object.acl.put(acl: "public-read") if SiteSetting.s3_use_acls

                # Create new filename for the converted video
                new_filename = original_filename.sub(/\.[^.]+$/, "_converted.mp4")

                # Create a new optimized video record
                optimized_video =
                  OptimizedVideo.create_for(
                    upload,
                    new_filename,
                    user_id,
                    filesize: object.size,
                    sha1: new_sha1,
                    url:
                      "//#{s3_store.s3_bucket}.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/#{path}",
                    extension: "mp4",
                  )

                if optimized_video
                  video_refs = UploadReference.where(upload_id: upload.id)
                  target_ids = video_refs.pluck(:target_id, :target_type)

                  # Just rebake the posts - the CookedPostProcessor will handle the URL updates
                  Post
                    .where(id: target_ids.map(&:first))
                    .find_each do |post|
                      Rails.logger.info("Rebaking post #{post.id} to use optimized video")
                      post.rebake!
                    end
                else
                  Rails.logger.error("Failed to create OptimizedVideo record")
                  Rails.logger.error("Upload ID: #{upload.id}")
                  Rails.logger.error("SHA1: #{new_sha1}")
                  Rails.logger.error(
                    "URL: //#{s3_store.s3_bucket}.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/#{path}",
                  )
                  raise "Failed to create optimized video record"
                end
              rescue => e
                Rails.logger.error("Error in video processing: #{e.message}")
                Rails.logger.error(e.backtrace.join("\n"))
                raise
              end
            else
              Rails.logger.error("File not found in S3: #{path}")
              raise "File not found in S3: #{path}"
            end
          rescue Aws::S3::Errors::ServiceError => e
            Rails.logger.error("Error getting S3 object info: #{e.message}")
            raise
          end
        when "ERROR"
          error_message = response.job.error_message || "Unknown error"
          Rails.logger.error("MediaConvert job failed: #{error_message}")
        when "SUBMITTED", "PROGRESSING"
          # Re-enqueue the job to check again with all the same parameters
          Jobs.enqueue_in(
            30.seconds,
            :check_media_convert_status,
            upload_id: upload_id,
            job_id: job_id,
            new_sha1: new_sha1,
            output_path: output_path,
            original_filename: original_filename,
            user_id: user_id,
          )
        else
          Rails.logger.warn("Unexpected MediaConvert job status: #{status}")
        end
      rescue Aws::MediaConvert::Errors::ServiceError => e
        Rails.logger.error("Error checking MediaConvert job status: #{e.message}")
        raise
      end
    end
  end
end
