# frozen_string_literal: true

class Admin::EmojiController < Admin::AdminController
  skip_before_action :check_xhr, only: [:export]

  def index
    render_serialized(
      Emoji.custom.sort_by do |emoji|
        [emoji.group == "default" ? 0 : 1, emoji.group.downcase, emoji.name.downcase]
      end,
      EmojiSerializer,
      root: false,
    )
  end

  # NOTE: This kind of custom logic also needs to be implemented to
  # be run in the ExternalUploadManager when a direct S3 upload is completed,
  # related to preventDirectS3Uploads in the UppyUploadMixin.
  #
  # Until then, preventDirectS3Uploads is set to true in the UppyUploadMixin.
  def create
    file = params[:file] || params[:files].first
    name = params[:name] || File.basename(file.original_filename, ".*")
    group = params[:group] ? params[:group].downcase : nil

    hijack do
      # fix the name
      name = File.basename(name, ".*")
      name = Emoji.sanitize_emoji_name(name)
      upload =
        UploadCreator.new(file.tempfile, file.original_filename, type: "custom_emoji").create_for(
          current_user.id,
        )

      good = true

      data =
        if upload.persisted?
          custom_emoji =
            CustomEmoji.new(name: name, upload: upload, group: group, user: current_user)

          if custom_emoji.save
            StaffActionLogger.new(current_user).log_custom_emoji_create(name, group: group)

            Emoji.clear_cache
            { name: custom_emoji.name, url: custom_emoji.upload.url, group: group }
          else
            good = false
            failed_json.merge(errors: custom_emoji.errors.full_messages)
          end
        else
          good = false
          failed_json.merge(errors: upload.errors.full_messages)
        end

      render json: data.as_json, status: good ? 200 : 422
    end
  end

  def export
    CustomEmoji::Export.call(service_params) do |result|
      on_success do |archive:|
        send_data archive,
                  type: "application/zip",
                  disposition: "attachment",
                  filename: "emojis.zip"
      end
      on_failed_contract do
        render json: failed_json.merge(errors: [I18n.t("emoji.export.no_selection")]),
               status: :unprocessable_entity
      end
      on_model_not_found(:emojis) { render json: failed_json, status: :not_found }
    end
  end

  def import_preview
    hijack do
      CustomEmoji::PreviewImport.call(service_params) do |result|
        on_success do |token:, rows:|
          render json: {
                   token:,
                   rows:
                     ActiveModel::ArraySerializer.new(
                       rows,
                       each_serializer: CustomEmoji::ImportRowSerializer,
                     ).as_json,
                 }
        end
        on_failed_contract do
          render json: failed_json.merge(errors: [I18n.t("emoji.import.missing_file")]),
                 status: :unprocessable_entity
        end
        on_failed_policy(:manifest_not_empty) do
          render json: failed_json.merge(errors: [I18n.t("emoji.import.empty_manifest")]),
                 status: :unprocessable_entity
        end
        on_exceptions(CSV::MalformedCSVError) do
          render json: failed_json.merge(errors: [I18n.t("emoji.import.invalid_csv")]),
                 status: :unprocessable_entity
        end
        on_exceptions(Compression::SafeZipReader::MissingEntryError) do
          render json: failed_json.merge(errors: [I18n.t("emoji.import.missing_csv")]),
                 status: :unprocessable_entity
        end
        on_exceptions(Compression::SafeZipReader::TooManyEntriesError) do
          render json: failed_json.merge(errors: [I18n.t("emoji.import.too_many_entries")]),
                 status: :unprocessable_entity
        end
        on_exceptions(Compression::SafeZipReader::EntryTooLargeError) do
          render json: failed_json.merge(errors: [I18n.t("emoji.import.file_too_large")]),
                 status: :unprocessable_entity
        end
        on_exceptions(Compression::SafeZipReader::SuspiciousEntryError) do
          render json: failed_json.merge(errors: [I18n.t("emoji.import.suspicious_entry")]),
                 status: :unprocessable_entity
        end
      end
    end
  end

  def import_confirm
    CustomEmoji::ConfirmImport.call(service_params) do |result|
      on_success { |report:| render json: report }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages),
               status: :unprocessable_entity
      end
      on_model_not_found(:rows) do
        render json: failed_json.merge(errors: [I18n.t("emoji.import.session_expired")]),
               status: :unprocessable_entity
      end
      on_exceptions(ActiveRecord::RecordInvalid) do |exception|
        render json: failed_json.merge(errors: [exception.message]), status: :unprocessable_entity
      end
    end
  end

  def destroy
    name = params.require(:id)

    # NOTE: the upload will automatically be removed by the 'clean_up_uploads' job
    emoji = CustomEmoji.find_by(name: name)

    if emoji.present?
      StaffActionLogger.new(current_user).log_custom_emoji_destroy(name)
      emoji.destroy!
    end

    Emoji.clear_cache

    Jobs.enqueue(:rebake_custom_emoji_posts, name: name)

    render json: success_json
  end
end
