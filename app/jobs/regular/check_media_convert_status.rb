# frozen_string_literal: true

require 'aws-sdk-mediaconvert'
require 'file_store/s3_store'
require 'upload_creator'

module Jobs
  class CheckMediaConvertStatus < ::Jobs::Base
    sidekiq_options queue: 'low'

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
        client = Aws::MediaConvert::Client.new(
          region: SiteSetting.s3_region,
          credentials: Aws::Credentials.new(
            SiteSetting.s3_access_key_id,
            SiteSetting.s3_secret_access_key
          )
        )

        resp = client.describe_endpoints
        endpoint = resp.endpoints[0].url

        mediaconvert_client = Aws::MediaConvert::Client.new(
          region: SiteSetting.s3_region,
          credentials: Aws::Credentials.new(
            SiteSetting.s3_access_key_id,
            SiteSetting.s3_secret_access_key
          ),
          endpoint: endpoint
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
              "#{output_path}.mp4",  # MediaConvert adds .mp4
              output_path  # Try without extension as fallback
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
                # Create a new upload record for the converted file using UploadCreator
                user = User.find(user_id)
                new_filename = original_filename.sub(/\.[^.]+$/, '_converted.mp4')

                # Create a temporary file with the S3 object
                temp_file = Tempfile.new(['converted', '.mp4'])
                begin
                  object.download_file(temp_file.path)
                  temp_file.rewind

                  creator = UploadCreator.new(
                    temp_file,
                    new_filename,
                    skip_validations: true,
                    filesize: object.size,
                    sha1: new_sha1,
                    url: "//#{s3_store.s3_bucket}/#{actual_path}",
                    width: 1920,
                    height: 1080,
                    thumbnail_width: 1920,
                    thumbnail_height: 1080,
                    extension: 'mp4'
                  )

                  new_upload = creator.create_for(user.id)

                  # Find the thumbnail upload by looking for original_filename that starts with the video's SHA1
                  thumbnail_upload = Upload.where("original_filename LIKE ?", "#{upload.sha1}.%").first
                  new_thumbnail_upload = nil

                  if thumbnail_upload

                    # Extract the path from the thumbnail's URL
                    url = thumbnail_upload.url.sub(%r{^//}, '')  # Remove leading //
                    domain, path = url.split('/', 2)
                    original_thumbnail_path = path
                    new_thumbnail_path = "original/1X/#{new_upload.sha1}#{File.extname(thumbnail_upload.original_filename)}"

                    begin
                      # Check if original thumbnail exists
                      original_thumbnail = s3_store.object_from_path(original_thumbnail_path)
                      if original_thumbnail.exists?

                        # Copy the thumbnail to the new path
                        s3_store.copy_file(
                          "//#{s3_store.s3_bucket}/#{original_thumbnail_path}",
                          original_thumbnail_path,
                          new_thumbnail_path
                        )

                        # Create a temporary file with the thumbnail
                        temp_thumbnail = Tempfile.new(['thumbnail', File.extname(thumbnail_upload.original_filename)])
                        begin
                          original_thumbnail.download_file(temp_thumbnail.path)
                          temp_thumbnail.rewind

                          # Create a new upload record for the thumbnail using UploadCreator
                          # We use new_upload.sha1 in the filename but let UploadCreator handle the SHA1
                          thumbnail_creator = UploadCreator.new(
                            temp_thumbnail,
                            "#{new_upload.sha1}#{File.extname(thumbnail_upload.original_filename)}",  # Use converted video's actual SHA1 in filename
                            skip_validations: true,
                            filesize: original_thumbnail.size,
                            url: "//#{s3_store.s3_bucket}/#{new_thumbnail_path}",
                            width: thumbnail_upload.width,
                            height: thumbnail_upload.height,
                            thumbnail_width: thumbnail_upload.thumbnail_width,
                            thumbnail_height: thumbnail_upload.thumbnail_height,
                            extension: thumbnail_upload.extension,
                            type: 'thumbnail'  # Mark this as a thumbnail upload
                          )

                          new_thumbnail_upload = thumbnail_creator.create_for(user_id)
                        ensure
                          temp_thumbnail.close
                          temp_thumbnail.unlink
                        end
                      end
                    rescue => e
                      # Don't raise here, we want to continue even if thumbnail copy fails
                    end
                  else
                    # No thumbnail upload found for video SHA1
                  end

                  # Update references for both video and thumbnail
                  ref_count = UploadReference.where(upload_id: [upload.id, thumbnail_upload&.id].compact).count

                  # Update video references
                  video_refs = UploadReference.where(upload_id: upload.id)

                  # Get the target IDs before updating
                  target_ids = video_refs.pluck(:target_id, :target_type)

                  # Delete any existing references to the new upload for these targets
                  UploadReference.where(upload_id: new_upload.id, target_id: target_ids.map(&:first), target_type: target_ids.map(&:last).uniq).delete_all

                  # Update the references
                  video_updated = video_refs.update_all(upload_id: new_upload.id)

                  # Update thumbnail references if we have a new thumbnail
                  if new_thumbnail_upload && thumbnail_upload
                    thumbnail_refs = UploadReference.where(upload_id: thumbnail_upload.id)

                    # Get the target IDs before updating
                    thumbnail_target_ids = thumbnail_refs.pluck(:target_id, :target_type)

                    # Delete any existing references to the new thumbnail for these targets
                    UploadReference.where(upload_id: new_thumbnail_upload.id, target_id: thumbnail_target_ids.map(&:first), target_type: thumbnail_target_ids.map(&:last).uniq).delete_all

                    # Update the references
                    thumbnail_updated = thumbnail_refs.update_all(upload_id: new_thumbnail_upload.id)
                  end

                  # Update post content to point to new uploads
                  Post.where(id: target_ids.map(&:first)).find_each do |post|
                    original_raw = post.raw

                    # Update video references in post content
                    post.raw = post.raw.gsub(
                      %r{upload://#{upload.base62_sha1}(\.#{upload.extension})?}i,
                      new_upload.short_url
                    )

                    # Update thumbnail references if we have a new thumbnail
                    if new_thumbnail_upload && thumbnail_upload
                      post.raw = post.raw.gsub(
                        %r{upload://#{thumbnail_upload.base62_sha1}(\.#{thumbnail_upload.extension})?}i,
                        new_thumbnail_upload.short_url
                      )
                    end

                    if post.raw != original_raw
                      post.save!(validate: false)
                      post.rebake!

                    end
                  end

                ensure
                  temp_file.close
                  temp_file.unlink
                end
              rescue => e
                raise
              end
            else
              Rails.logger.error("File not found in S3: #{output_path}")
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
          Jobs.enqueue_in(30.seconds, :check_media_convert_status,
            upload_id: upload_id,
            job_id: job_id,
            new_sha1: new_sha1,
            output_path: output_path,
            original_filename: original_filename,
            user_id: user_id
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