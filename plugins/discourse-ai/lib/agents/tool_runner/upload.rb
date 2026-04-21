# frozen_string_literal: true

module DiscourseAi
  module Agents
    class ToolRunner
      module Upload
        def attach_upload(mini_racer_context)
          mini_racer_context.attach(
            "_upload_get_base64",
            ->(upload_id_or_url, max_pixels) do
              in_attached_function do
                return nil if upload_id_or_url.blank?

                upload = nil

                # Handle both upload ID and short URL
                if upload_id_or_url.to_s.start_with?("upload://")
                  # Handle short URL format
                  sha1 = ::Upload.sha1_from_short_url(upload_id_or_url)
                  return nil if sha1.blank?
                  upload = ::Upload.find_by(sha1: sha1)
                else
                  # Handle numeric ID
                  upload_id = upload_id_or_url.to_i
                  return nil if upload_id <= 0
                  upload = ::Upload.find_by(id: upload_id)
                end

                return nil if upload.nil?

                max_pixels = max_pixels&.to_i
                max_pixels = nil if max_pixels && max_pixels <= 0

                encoded_uploads =
                  DiscourseAi::Completions::UploadEncoder.encode(
                    upload_ids: [upload.id],
                    max_pixels: max_pixels || 10_000_000, # Default to 10M pixels if not specified
                  )

                encoded_uploads.first&.dig(:base64)
              end
            end,
          )
          mini_racer_context.attach(
            "_upload_get_url",
            ->(short_url) do
              in_attached_function do
                return nil if short_url.blank?

                sha1 = ::Upload.sha1_from_short_url(short_url)
                return nil if sha1.blank?

                upload = ::Upload.find_by(sha1: sha1)
                return nil if upload.nil?
                # TODO we may need to introduce an API to unsecure, secure uploads
                return nil if upload.secure?

                GlobalPath.full_cdn_url(upload.url)
              end
            end,
          )
          mini_racer_context.attach(
            "_upload_create",
            ->(filename, base_64_content) do
              begin
                in_attached_function do
                  # protect against misuse
                  filename = File.basename(filename)

                  Tempfile.create(filename) do |file|
                    file.binmode
                    file.write(Base64.decode64(base_64_content))
                    file.rewind

                    upload =
                      UploadCreator.new(
                        file,
                        filename,
                        for_private_message: @context.private_message,
                      ).create_for(@bot_user.id)

                    if upload&.persisted?
                      { "id" => upload.id, "short_url" => upload.short_url, "url" => upload.url }
                    else
                      error_msg =
                        upload&.errors&.full_messages&.join(", ") || "Upload creation failed"
                      { "error" => error_msg }
                    end
                  end
                end
              rescue => e
                { "error" => e.message }
              end
            end,
          )
        end
      end
    end
  end
end
