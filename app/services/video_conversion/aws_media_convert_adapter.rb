# frozen_string_literal: true
require "aws-sdk-mediaconvert"

module VideoConversion
  class AwsMediaConvertAdapter < BaseAdapter
    ADAPTER_NAME = "aws_mediaconvert"

    def convert
      return false if !valid_settings?

      begin
        new_sha1 = SecureRandom.hex(20)

        # Use FileStore::BaseStore logic to generate the path
        # Create a temporary upload object to leverage the path generation logic
        temp_upload = build_temp_upload_for_path_generation(new_sha1)
        output_path = Discourse.store.get_path_for_upload(temp_upload).sub(/\.mp4$/, "")

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
        settings = build_conversion_settings(input_path, output_path)

        begin
          response =
            mediaconvert_client.create_job(
              role: SiteSetting.mediaconvert_role_arn,
              settings: settings,
              status_update_interval: "SECONDS_10",
              user_metadata: {
                "upload_id" => @upload.id.to_s,
                "new_sha1" => new_sha1,
                "output_path" => output_path,
              },
            )

          # Enqueue status check job
          Jobs.enqueue_in(
            30.seconds,
            :check_video_conversion_status,
            upload_id: @upload.id,
            job_id: response.job.id,
            new_sha1: new_sha1,
            output_path: output_path,
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

    def handle_completion(job_id, output_path, new_sha1)
      s3_store = FileStore::S3Store.new
      path = "#{output_path}.mp4"
      object = s3_store.object_from_path(path)

      return false if !object&.exists?

      begin
        url = "//#{s3_store.s3_bucket}.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/#{path}"

        optimized_video = create_optimized_video_record(output_path, new_sha1, object.size, url)

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
          },
        )
        false
      end
    end

    private

    def valid_settings?
      SiteSetting.video_conversion_enabled && SiteSetting.mediaconvert_role_arn.present?
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

      # Only set credentials if both are provided
      # If neither provided, AWS SDK will auto-discover (IAM roles, instance profile, etc.)
      if SiteSetting.s3_access_key_id.present? && SiteSetting.s3_secret_access_key.present?
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
      SiteSetting.Upload.s3_upload_bucket
    end

    def build_conversion_settings(input_path, output_path)
      self.class.build_conversion_settings(input_path, output_path)
    end

    def self.build_conversion_settings(input_path, output_path)
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
                destination: "s3://#{s3_upload_bucket}/#{output_path}",
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
