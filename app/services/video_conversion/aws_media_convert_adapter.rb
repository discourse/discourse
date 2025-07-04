# frozen_string_literal: true
require "aws-sdk-mediaconvert"

module VideoConversion
  class AwsMediaConvertAdapter < BaseAdapter
    def convert
      return false unless valid_settings?

      begin
        new_sha1 = SecureRandom.hex(20)
        output_path = "optimized/videos/#{new_sha1}"

        # Extract the path from the URL
        # The URL format is: //bucket.s3.dualstack.region.amazonaws.com/path/to/file
        # or: //bucket.s3.region.amazonaws.com/path/to/file
        url = @upload.url.sub(%r{^//}, "") # Remove leading //

        # Split on the first / to separate the domain from the path
        domain, path = url.split("/", 2)

        # Verify the domain contains our bucket
        unless domain&.include?(SiteSetting.s3_upload_bucket)
          raise Discourse::InvalidParameters.new(
                  "Upload URL domain does not contain expected bucket name: #{SiteSetting.s3_upload_bucket}",
                )
        end

        input_path = "s3://#{SiteSetting.s3_upload_bucket}/#{path}"
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
          Rails.logger.error(
            "MediaConvert job creation failed for upload #{@upload.id}. " \
              "Error: #{e.class.name} - #{e.message}" \
              "#{e.respond_to?(:code) ? " (Code: #{e.code})" : ""}" \
              "#{e.respond_to?(:context) ? " (Request ID: #{e.context.request_id})" : ""}",
          )
          Discourse.warn_exception(
            e,
            message: "MediaConvert job creation failed",
            env: {
              upload_id: @upload.id,
            },
          )
          false
        rescue => e
          Rails.logger.error(
            "Unexpected error creating MediaConvert job for upload #{@upload.id}: #{e.class.name} - #{e.message}",
          )
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
        Rails.logger.error(
          "Unexpected error in video conversion for upload #{@upload.id}: #{e.class.name} - #{e.message}",
        )
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
        :complete
      when "ERROR"
        Rails.logger.error("MediaConvert job #{job_id} failed")
        :error
      when "SUBMITTED", "PROGRESSING"
        :pending
      else
        Rails.logger.warn(
          "Unexpected MediaConvert job status for job #{job_id}: #{response.job.status}",
        )
        :error
      end
    end

    def handle_completion(job_id, output_path, new_sha1)
      s3_store = FileStore::S3Store.new
      path = "#{output_path}.mp4"
      object = s3_store.object_from_path(path)

      return false unless object&.exists?

      begin
        optimized_video =
          create_optimized_video_record(
            output_path,
            new_sha1,
            object.size,
            "//#{s3_store.s3_bucket}.s3.dualstack.#{SiteSetting.s3_region}.amazonaws.com/#{path}",
          )

        if optimized_video
          update_posts_with_optimized_video
          true
        else
          Rails.logger.error("Failed to create OptimizedVideo record for upload #{@upload.id}")
          false
        end
      rescue => e
        Rails.logger.error(
          "Error processing video completion for upload #{@upload.id}: #{e.message}",
        )
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
      SiteSetting.video_conversion_enabled && SiteSetting.mediaconvert_role_arn.present? &&
        SiteSetting.mediaconvert_endpoint.present?
    end

    def mediaconvert_client
      @mediaconvert_client ||=
        begin
          # For some reason the endpoint is not visible in the aws console UI so we need to get it from the API
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

          Aws::MediaConvert::Client.new(
            region: SiteSetting.s3_region,
            credentials:
              Aws::Credentials.new(SiteSetting.s3_access_key_id, SiteSetting.s3_secret_access_key),
            endpoint: SiteSetting.mediaconvert_endpoint,
          )
        end
    end

    def update_posts_with_optimized_video
      video_refs = UploadReference.where(upload_id: @upload.id)
      target_ids = video_refs.pluck(:target_id, :target_type)

      Post
        .where(id: target_ids.map(&:first))
        .find_each do |post|
          Rails.logger.info("Rebaking post #{post.id} to use optimized video")
          post.rebake!
        end
    end

    def build_conversion_settings(input_path, output_path)
      settings = {
        timecode_config: {
          source: "ZEROBASED",
        },
        output_groups: [
          {
            name: "File Group",
            output_group_settings: {
              type: "FILE_GROUP_SETTINGS",
              file_group_settings: {
                destination: "s3://#{SiteSetting.s3_upload_bucket}/#{output_path}",
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
