# frozen_string_literal: true

module DiscourseAi
  module Rag
    class DocumentSourceRefresher
      RETRY_INTERVAL = 1.hour

      def self.refresh(source)
        new(source).refresh
      end

      def initialize(source)
        @source = source
      end

      def refresh
        result =
          WebPageFetcher.fetch(
            url: @source.url,
            etag: @source.etag,
            last_modified: @source.last_modified,
          )

        if result[:not_modified]
          mark_success
        else
          replace_upload(result)
        end
      rescue WebPageFetcher::FetchError => error
        mark_failure(error)
      end

      private

      def replace_upload(result)
        upload = create_upload(result)
        old_upload_id = @source.upload_id

        RagDocumentSource.transaction do
          @source.update_columns(
            upload_id: upload.id,
            etag: result[:etag],
            last_modified: result[:last_modified],
            last_fetched_at: Time.zone.now,
            next_refresh_at: @source.refresh_interval_hours.hours.from_now,
            last_error_at: nil,
            last_error: nil,
            updated_at: Time.zone.now,
          )

          if old_upload_id.present? && old_upload_id != upload.id
            RagDocumentFragment.where(target: @source.target, upload_id: old_upload_id).destroy_all
            UploadReference.where(target: @source.target, upload_id: old_upload_id).destroy_all
          end
        end

        RagDocumentFragment.link_target_and_uploads(@source.target, [upload.id])
      end

      def create_upload(result)
        content = <<~TEXT
          [[metadata #{JSON.generate(source_url: result[:url])}]]
          #{result[:text]}
        TEXT

        Tempfile.create(["rag-url-source-#{@source.id}", ".txt"]) do |file|
          file.write(content)
          file.rewind

          upload =
            UploadCreator.new(
              file,
              "url-source-#{@source.id}.txt",
              type: "discourse_ai_rag_upload",
              origin: result[:url],
              skip_validations: true,
            ).create_for(Discourse.system_user.id)

          if !upload.persisted?
            raise WebPageFetcher::FetchError, upload.errors.full_messages.join(", ")
          end

          return upload
        end
      end

      def mark_success
        @source.update_columns(
          last_fetched_at: Time.zone.now,
          next_refresh_at: @source.refresh_interval_hours.hours.from_now,
          last_error_at: nil,
          last_error: nil,
          updated_at: Time.zone.now,
        )
      end

      def mark_failure(error)
        @source.update_columns(
          next_refresh_at: RETRY_INTERVAL.from_now,
          last_error_at: Time.zone.now,
          last_error: error.message.to_s.truncate(4000),
          updated_at: Time.zone.now,
        )
      end
    end
  end
end
