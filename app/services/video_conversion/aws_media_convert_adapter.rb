# frozen_string_literal: true
require "aws-sdk-mediaconvert"

module VideoConversion
  class AwsMediaConvertAdapter < BaseAdapter
    ADAPTER_NAME = "aws_mediaconvert"

    def convert
      return false if !valid_settings?

      begin
        new_sha1 = SecureRandom.hex(20)

        # Extract the path from the URL
        # The URL format is: //bucket.s3.dualstack.region.amazonaws.com/path/to/file
        # or: //bucket.s3.region.amazonaws.com/path/to/file
        url = @upload.url.sub(%r{^//}, "") # Remove leading //

        # Split on the first / to separate the domain from the path
        domain, path = url.split("/", 2)

        # Verify the domain contains our bucket
        if !domain&.include?(s3_upload_bucket)
          raise Discourse::InvalidParameters.new(
                  "Upload URL domain for upload ID #{@upload.id} does not contain expected bucket name: #{s3_upload_bucket}",
                )
        end

        input_path = "s3://#{s3_upload_bucket}/#{path}"

        settings = build_conversion_settings(input_path, new_sha1)

        begin
          response =
            mediaconvert_client.create_job(
              role: SiteSetting.mediaconvert_role_arn,
              settings: settings,
              status_update_interval: "SECONDS_10",
              user_metadata: {
                "upload_id" => @upload.id.to_s,
                "new_sha1" => new_sha1,
              },
            )

          # Enqueue status check job
          Jobs.enqueue_in(
            30.seconds,
            :check_video_conversion_status,
            upload_id: @upload.id,
            job_id: response.job.id,
            new_sha1: new_sha1,
            original_filename: @upload.original_filename,
            user_id: @upload.user_id,
            adapter_type: "aws_mediaconvert",
          )

          true # Return true on success
        rescue Aws::MediaConvert::Errors::ServiceError => e
          Discourse.warn_exception(
            e,
            message: "MediaConvert job creation failed",
            env: {
              upload_id: @upload.id,
            },
          )
          false
        rescue => e
          Discourse.warn_exception(
            e,
            message: "Unexpected error in MediaConvert job creation",
            env: {
              upload_id: @upload.id,
            },
          )
          false
        end
      rescue Discourse::InvalidParameters => e
        Rails.logger.error("Invalid parameters for upload #{@upload.id}: #{e.message}")
        false
      rescue => e
        Discourse.warn_exception(
          e,
          message: "Unexpected error in video conversion",
          env: {
            upload_id: @upload.id,
          },
        )
        false
      end
    end

    def check_status(job_id)
      response = mediaconvert_client.get_job(id: job_id)

      case response.job.status
      when "COMPLETE"
        STATUS_COMPLETE
      when "ERROR"
        Rails.logger.error(
          "MediaConvert job #{job_id} failed. Error Code: #{response.job.error_code}, " \
            "Error Message: #{response.job.error_message}, Upload ID: #{@upload.id}",
        )
        STATUS_ERROR
      when "SUBMITTED", "PROGRESSING"
        STATUS_PENDING
      else
        Rails.logger.warn(
          "Unexpected MediaConvert job status for job #{job_id}: #{response.job.status}",
        )
        STATUS_ERROR
      end
    end

    def handle_completion(job_id, new_sha1)
      s3_store = FileStore::S3Store.new
      temp_path = File.join(SiteSetting.mediaconvert_output_subdirectory, "#{new_sha1}.mp4")

      filesize = find_temp_file(s3_store, temp_path)
      return false unless filesize

      begin
        final_path = get_final_upload_path(new_sha1)
        etag, destination_path = copy_file_to_final_location(s3_store, temp_path, final_path)
        return false unless etag

        source_path = get_s3_path(temp_path)
        update_file_acl(s3_store, final_path, destination_path)
        remove_temp_file(s3_store, source_path)

        url = build_file_url(s3_store, destination_path)
        output_path = get_output_path_for_record(final_path)
        optimized_video =
          create_optimized_video_record(output_path, new_sha1, filesize, url, etag: etag)

        if optimized_video
          update_posts_with_optimized_video
          true
        else
          Rails.logger.error("Failed to create OptimizedVideo record for upload #{@upload.id}")
          false
        end
      rescue => e
        Discourse.warn_exception(
          e,
          message: "Error in video processing completion",
          env: {
            upload_id: @upload.id,
            job_id: job_id,
            temp_path: temp_path,
            error_class: e.class.name,
            error_message: e.message,
          },
        )
        false
      end
    end

    private

    def valid_settings?
      SiteSetting.video_conversion_enabled && SiteSetting.mediaconvert_role_arn.present?
    end

    def find_temp_file(s3_store, temp_path)
      temp_object = s3_store.object_from_path(temp_path)
      unless temp_object&.exists?
        Rails.logger.error(
          "MediaConvert temp file not found at #{temp_path} for upload #{@upload.id}",
        )
        return nil
      end

      temp_object.size
    end

    def get_final_upload_path(new_sha1)
      temp_upload = build_temp_upload_for_path_generation(new_sha1)
      Discourse.store.get_path_for_upload(temp_upload)
    end

    def copy_file_to_final_location(s3_store, temp_path, final_path)
      s3_helper = s3_store.s3_helper
      bucket_name = s3_helper.s3_bucket_name
      s3_resource = Aws::S3::Resource.new(client: s3_helper.s3_client)
      source_bucket = s3_resource.bucket(bucket_name)

      source_path = get_s3_path(temp_path)
      source_object = source_bucket.object(source_path)
      unless source_object.exists?
        Rails.logger.error(
          "MediaConvert temp file not found at #{source_path} for upload #{@upload.id}, bucket=#{bucket_name}",
        )
        return nil, nil
      end

      destination_path = get_s3_path(final_path)
      destination_object = source_bucket.object(destination_path)

      copy_options = s3_store.default_s3_options(secure: @upload.secure?)
      if source_object.size > S3Helper::FIFTEEN_MEGABYTES
        copy_options[:multipart_copy] = true
        copy_options[:content_length] = source_object.size
      end

      begin
        response = destination_object.copy_from(source_object, copy_options)

        etag =
          if response.respond_to?(:copy_object_result)
            response.copy_object_result.etag
          else
            response.data.etag
          end
        etag = etag.gsub('"', "")

        unless destination_object.exists?
          Rails.logger.error(
            "MediaConvert copy completed but destination file not found at #{destination_path} for upload #{@upload.id}",
          )
          return nil, nil
        end

        [etag, destination_path]
      rescue Aws::S3::Errors::NotFound => e
        Rails.logger.error(
          "MediaConvert copy failed - source or destination not found: #{e.message} (source: #{source_path}, destination: #{destination_path}) for upload #{@upload.id}",
        )
        [nil, nil]
      rescue => e
        Rails.logger.error(
          "MediaConvert copy failed: #{e.class.name} - #{e.message} (source: #{source_path}, destination: #{destination_path}) for upload #{@upload.id}",
        )
        raise
      end
    end

    def update_file_acl(s3_store, final_path, destination_path)
      # For update_file_access_control, we need the path that matches where the file actually is
      # The file is at destination_path in S3, but update_file_access_control expects a path
      # that will be processed by s3_helper.object(path), which calls get_path_for_s3_upload(path)
      # So we need to pass the path WITHOUT bucket folder path (it will be added by s3_helper)
      # But WITH multisite path if in multisite mode (since that's where the file actually is)
      final_path_for_acl =
        if Rails.configuration.multisite
          File.join(build_multisite_path, final_path)
        else
          final_path
        end

      begin
        s3_store.update_file_access_control(final_path_for_acl, @upload.secure?)
      rescue Aws::S3::Errors::NotFound => e
        Rails.logger.error(
          "MediaConvert file not found when updating access control at #{final_path_for_acl} (full path: #{destination_path}) for upload #{@upload.id}: #{e.message}",
        )
        raise
      end
    end

    def remove_temp_file(s3_store, source_path)
      s3_helper = s3_store.s3_helper
      begin
        s3_helper.delete_object(source_path)
      rescue => e
        # Log but don't fail if deletion fails - file will be cleaned up later
        Rails.logger.warn(
          "Failed to delete temporary MediaConvert file #{source_path}: #{e.message}",
        )
      end
    end

    def build_file_url(s3_store, destination_path)
      "//#{s3_store.s3_bucket}.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com#{destination_path}"
    end

    def get_output_path_for_record(final_path)
      final_path_for_acl =
        if Rails.configuration.multisite
          File.join(build_multisite_path, final_path)
        else
          final_path
        end
      final_path_for_acl.sub(/\.mp4$/, "")
    end

    def get_s3_path(path)
      if Rails.configuration.multisite
        File.join(build_multisite_path, path)
      else
        path
      end
    end

    def build_multisite_path
      path = File.join("uploads", RailsMultisite::ConnectionManagement.current_db)
      "#{path}/"
    end

    def build_temp_upload_for_path_generation(new_sha1)
      # Create a temporary upload object to leverage FileStore::BaseStore path generation
      # This object is only used for path generation and won't be saved to the database
      Upload.new(
        id: @upload.id, # Use the same ID to get the same depth calculation
        sha1: new_sha1,
        extension: "mp4",
      )
    end

    def mediaconvert_client
      @mediaconvert_client ||= build_client
    end

    def build_client
      # For some reason the endpoint is not visible in the aws console UI so we need to get it from the API
      if SiteSetting.mediaconvert_endpoint.blank?
        client = create_basic_client
        resp = client.describe_endpoints
        SiteSetting.mediaconvert_endpoint = resp.endpoints[0].url
      end

      # Validate that we have an endpoint before proceeding
      if SiteSetting.mediaconvert_endpoint.blank?
        error_msg = "MediaConvert endpoint is required but could not be discovered"
        Discourse.warn_exception(
          StandardError.new(error_msg),
          message: error_msg,
          env: {
            upload_id: @upload.id,
          },
        )
        raise StandardError, error_msg
      end

      create_basic_client(endpoint: SiteSetting.mediaconvert_endpoint)
    end

    def create_basic_client(endpoint: nil)
      client_options = { region: SiteSetting.s3_region }
      client_options[:endpoint] = endpoint if endpoint.present?

      if !SiteSetting.s3_use_iam_profile
        client_options[:credentials] = Aws::Credentials.new(
          SiteSetting.s3_access_key_id,
          SiteSetting.s3_secret_access_key,
        )
      end

      Aws::MediaConvert::Client.new(client_options)
    end

    def update_posts_with_optimized_video
      post_ids = UploadReference.where(upload_id: @upload.id, target_type: "Post").pluck(:target_id)

      Post
        .where(id: post_ids)
        .find_each do |post|
          Rails.logger.info("Rebaking post #{post.id} to use optimized video")
          post.rebake!
        end
    end

    def s3_upload_bucket
      self.class.s3_upload_bucket
    end

    def self.s3_upload_bucket
      # MediaConvert needs just the bucket name, not the folder path
      # If s3_upload_bucket is "bucket-name/folder", we need just "bucket-name"
      bucket_name, _folder_path =
        S3Helper.get_bucket_and_folder_path(SiteSetting.Upload.s3_upload_bucket)
      bucket_name
    end

    def build_conversion_settings(input_path, output_path)
      self.class.build_conversion_settings(input_path, output_path)
    end

    def self.build_conversion_settings(input_path, temp_output_filename)
      # temp_output_filename is just the filename without extension (e.g., "new_sha1")
      # MediaConvert will automatically add .mp4 extension based on container type
      # We write it to the subdirectory as a temporary location
      subdirectory = SiteSetting.mediaconvert_output_subdirectory
      destination_path = File.join(subdirectory, temp_output_filename)

      {
        timecode_config: {
          source: "ZEROBASED",
        },
        output_groups: [
          {
            name: "File Group",
            output_group_settings: {
              type: "FILE_GROUP_SETTINGS",
              file_group_settings: {
                destination: "s3://#{s3_upload_bucket}/#{destination_path}",
              },
            },
            outputs: [
              {
                container_settings: {
                  container: "MP4",
                },
                video_description: {
                  codec_settings: {
                    codec: "H_264",
                    h264_settings: {
                      bitrate: 2_000_000,
                      rate_control_mode: "CBR",
                    },
                  },
                },
                audio_descriptions: [
                  {
                    codec_settings: {
                      codec: "AAC",
                      aac_settings: {
                        bitrate: 96_000,
                        sample_rate: 48_000,
                        coding_mode: "CODING_MODE_2_0",
                      },
                    },
                  },
                ],
              },
            ],
          },
        ],
        inputs: [
          {
            file_input: input_path,
            audio_selectors: {
              "Audio Selector 1": {
                default_selection: "DEFAULT",
              },
            },
            video_selector: {
            },
          },
        ],
      }
    end
  end
end
