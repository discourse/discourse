# frozen_string_literal: true

require "aws-sdk-mediaconvert"
require "file_store/s3_store"
require "upload_creator"

module Jobs
  class CheckMediaConvertStatus < ::Jobs::Base
    sidekiq_options queue: "low", concurrency: 5

    def execute(args)
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
        client =
          Aws::MediaConvert::Client.new(
            region: SiteSetting.s3_region,
            credentials:
              Aws::Credentials.new(SiteSetting.s3_access_key_id, SiteSetting.s3_secret_access_key),
          )

        resp = client.describe_endpoints
        endpoint = resp.endpoints[0].url

        mediaconvert_client =
          Aws::MediaConvert::Client.new(
            region: SiteSetting.s3_region,
            credentials:
              Aws::Credentials.new(SiteSetting.s3_access_key_id, SiteSetting.s3_secret_access_key),
            endpoint: endpoint,
          )

        # Get job status
        response = mediaconvert_client.get_job(id: job_id)
        status = response.job.status

        case status
        when "COMPLETE"
          s3_store = FileStore::S3Store.new

          begin
            # Try both the expected path and the path with .mp4 suffix
            paths_to_try = [
              "#{output_path}.mp4", # MediaConvert adds .mp4
              output_path, # Try without extension as fallback
            ]

            object = nil
            actual_path = nil

            paths_to_try.each do |path|
              temp_object = s3_store.object_from_path(path)
              if temp_object.exists?
                object = temp_object
                actual_path = path
                break
              end
            end

            if object&.exists?
              begin
                Rails.logger.info("Found converted video in S3 at path: #{actual_path}")
                Rails.logger.info("Object size: #{object.size}, SHA1: #{new_sha1}")

                # Set ACL to public-read for the optimized video, matching the pattern used for optimized images
                if SiteSetting.s3_use_acls
                  object.acl.put(acl: "public-read")
                  Rails.logger.info("Set ACL to public-read for video at path: #{actual_path}")
                end

                # Create new filename for the converted video
                new_filename = original_filename.sub(/\.[^.]+$/, "_converted.mp4")
                Rails.logger.info("!!!!!!!!!! New filename: #{new_filename}")

                # Create a new optimized video record
                Rails.logger.info(
                  "Attempting to create OptimizedVideo record for upload_id: #{upload.id}",
                )
                optimized_video =
                  OptimizedVideo.create_for(
                    upload,
                    new_filename,
                    user_id,
                    filesize: object.size,
                    sha1: new_sha1,
                    url:
                      "//#{s3_store.s3_bucket}.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/#{actual_path}",
                    extension: "mp4",
                  )

                if optimized_video
                  Rails.logger.info(
                    "Successfully created OptimizedVideo record with ID: #{optimized_video.id}",
                  )
                  Rails.logger.info("OptimizedVideo URL: #{optimized_video.url}")
                  Rails.logger.info("OptimizedVideo SHA1: #{optimized_video.sha1}")

                  # Find the thumbnail upload by looking for original_filename that starts with the video's SHA1
                  thumbnail_upload =
                    Upload.where("original_filename LIKE ?", "#{upload.sha1}.%").first
                  Rails.logger.info("Found thumbnail upload: #{thumbnail_upload&.id}")

                  new_thumbnail_upload = nil

                  if thumbnail_upload
                    # Extract the path from the thumbnail's URL
                    url = thumbnail_upload.url.sub(%r{^//}, "") # Remove leading //
                    domain, path = url.split("/", 2)
                    original_thumbnail_path = path
                    new_thumbnail_path =
                      "original/1X/#{optimized_video.sha1}#{File.extname(thumbnail_upload.original_filename)}"
                    Rails.logger.info("New thumbnail path: #{new_thumbnail_path}")

                    begin
                      # Check if original thumbnail exists
                      original_thumbnail = s3_store.object_from_path(original_thumbnail_path)
                      Rails.logger.info("Original thumbnail exists: #{original_thumbnail.exists?}")

                      if original_thumbnail.exists?
                        # Copy the thumbnail to the new path
                        Rails.logger.info("Copying thumbnail to new path")
                        s3_store.copy_file(
                          "//#{s3_store.s3_bucket}/#{original_thumbnail_path}",
                          original_thumbnail_path,
                          new_thumbnail_path,
                        )

                        # Create a temporary file with the thumbnail
                        temp_thumbnail =
                          Tempfile.new(
                            ["thumbnail", File.extname(thumbnail_upload.original_filename)],
                          )
                        begin
                          original_thumbnail.download_file(temp_thumbnail.path)
                          temp_thumbnail.rewind

                          # Create a new upload record for the thumbnail using UploadCreator
                          Rails.logger.info("Creating new thumbnail upload record")
                          thumbnail_creator =
                            UploadCreator.new(
                              temp_thumbnail,
                              "#{optimized_video.sha1}#{File.extname(thumbnail_upload.original_filename)}",
                              skip_validations: true,
                              filesize: original_thumbnail.size,
                              url: "//#{s3_store.s3_bucket}/#{new_thumbnail_path}",
                              width: thumbnail_upload.width,
                              height: thumbnail_upload.height,
                              thumbnail_width: thumbnail_upload.thumbnail_width,
                              thumbnail_height: thumbnail_upload.thumbnail_height,
                              extension: thumbnail_upload.extension,
                              type: "thumbnail",
                            )

                          new_thumbnail_upload = thumbnail_creator.create_for(user_id)
                          Rails.logger.info(
                            "Created new thumbnail upload with ID: #{new_thumbnail_upload&.id}",
                          )
                        ensure
                          temp_thumbnail.close
                          temp_thumbnail.unlink
                        end
                      end
                    rescue => e
                      Rails.logger.error("Error processing thumbnail: #{e.message}")
                      Rails.logger.error(e.backtrace.join("\n"))
                      # Don't raise here, we want to continue even if thumbnail copy fails
                    end
                  else
                    Rails.logger.info("No thumbnail upload found for video SHA1: #{upload.sha1}")
                  end

                  # Get posts that reference this upload
                  video_refs = UploadReference.where(upload_id: upload.id)
                  Rails.logger.info("Found #{video_refs.count} posts referencing this video")

                  # Get the target IDs before updating
                  target_ids = video_refs.pluck(:target_id, :target_type)
                  Rails.logger.info("Found #{target_ids.count} target posts to update")

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
                    "URL: //#{s3_store.s3_bucket}.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/#{actual_path}",
                  )
                  raise "Failed to create optimized video record"
                end
              rescue => e
                Rails.logger.error("Error in video processing: #{e.message}")
                Rails.logger.error(e.backtrace.join("\n"))
                raise
              end
            else
              Rails.logger.error("File not found in S3: #{output_path}")
              Rails.logger.error("Tried paths: #{paths_to_try.join(", ")}")
              raise "File not found in S3: #{output_path}"
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
