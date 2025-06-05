# frozen_string_literal: true

require 'aws-sdk-mediaconvert'

module Jobs
  class ConvertVideo < ::Jobs::Base
    sidekiq_options queue: 'low'

    def execute(args)
      return if args[:upload_id].blank?

      upload = Upload.find_by(id: args[:upload_id])
      return if upload.blank?

      # Check if this file has already been converted
      if upload.original_filename.end_with?('_converted.mp4')
        return
      end

      # Wait for upload to be complete in S3
      retry_count = args[:retry_count].to_i
      if upload.url.blank?
        if retry_count < 5  # Try up to 5 times with exponential backoff
          wait_time = (2 ** retry_count) * 5  # 5, 10, 20, 40, 80 seconds
          Jobs.enqueue_in(wait_time.seconds, :convert_video,
            upload_id: upload.id,
            retry_count: retry_count + 1
          )
          return
        else
          raise "Upload URL is still blank after 5 retries"
        end
      end

      # Validate upload URL
      if upload.url.blank?
        # Try to reload the upload to see if it's a stale record
        upload.reload
        if upload.url.blank?
          raise "Upload URL is blank for upload #{upload.id}"
        end
      end

      # Create MediaConvert client
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

      mediaconvert_role_arn = ENV['DISCOURSE_MEDIACONVERT_ROLE_ARN']
      raise "DISCOURSE_MEDIACONVERT_ROLE_ARN environment variable is not set" unless mediaconvert_role_arn

      new_sha1 = SecureRandom.hex(20)
      output_path = "original/1X/#{new_sha1}"

      # Extract the path from the URL
      # The URL format is: //bucket.s3.dualstack.region.amazonaws.com/path/to/file
      # or: //bucket.s3.region.amazonaws.com/path/to/file
      url = upload.url.sub(%r{^//}, '')  # Remove leading //

      # Split on the first / to separate the domain from the path
      domain, path = url.split('/', 2)

      # Verify the domain contains our bucket
      unless domain&.include?(SiteSetting.s3_upload_bucket)
        raise "Upload URL domain does not contain expected bucket name: #{SiteSetting.s3_upload_bucket}. URL: #{upload.url.inspect}"
      end

      input_path = "s3://#{SiteSetting.s3_upload_bucket}/#{path}"

      settings = {
        timecode_config: { source: "ZEROBASED" },
        output_groups: [
          {
            name: "File Group",
            output_group_settings: {
              type: "FILE_GROUP_SETTINGS",
              file_group_settings: {
                destination: "s3://#{SiteSetting.s3_upload_bucket}/#{output_path}"
              }
            },
            outputs: [
              {
                container_settings: {
                  container: "MP4"
                },
                video_description: {
                  codec_settings: {
                    codec: "H_264",
                    h264_settings: {
                      bitrate: 2000000,
                      rate_control_mode: "CBR"
                    }
                  }
                },
                audio_descriptions: [
                  {
                    codec_settings: {
                      codec: "AAC",
                      aac_settings: {
                        bitrate: 96000,
                        sample_rate: 48000,
                        coding_mode: "CODING_MODE_2_0"
                      }
                    }
                  }
                ]
              }
            ]
          }
        ],
        inputs: [
          {
            file_input: input_path,
            audio_selectors: {
              "Audio Selector 1": {
                default_selection: "DEFAULT"
              }
            },
            video_selector: {}
          }
        ]
      }

      begin
        # Create the MediaConvert job
        response = mediaconvert_client.create_job(
          role: mediaconvert_role_arn,
          settings: settings,
          status_update_interval: "SECONDS_10",
          user_metadata: {
            "upload_id" => upload.id.to_s,
            "new_sha1" => new_sha1,
            "output_path" => output_path
          }
        )

        # Enqueue a job to check the status with all necessary data
        Jobs.enqueue_in(30.seconds, :check_media_convert_status,
          upload_id: upload.id,
          job_id: response.job.id,
          new_sha1: new_sha1,
          output_path: output_path,
          original_filename: upload.original_filename,
          user_id: upload.user_id
        )

      rescue Aws::MediaConvert::Errors::ServiceError => e
        Rails.logger.error("MediaConvert job creation failed: #{e.message}")
        raise
      rescue StandardError => e
        Rails.logger.error("Unexpected error in MediaConvert job: #{e.message}")
        raise
      end
    end
  end
end