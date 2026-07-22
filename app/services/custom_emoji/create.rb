# frozen_string_literal: true

class CustomEmoji::Create
  include Service::Base

  UploadResult = Data.define(:upload) { delegate :errors, :persisted?, to: :upload }

  params do
    attribute :file
    attribute :files
    attribute :name, :string
    attribute :group, :string

    before_validation :prepare_attributes

    validates :file, presence: true

    private

    def prepare_attributes
      self.file ||= files&.first
      self.name = File.basename(name.nil? ? file&.original_filename.to_s : name, ".*")
      self.name = Emoji.sanitize_emoji_name(name)
      self.group = group&.downcase
    end
  end

  model :upload_result, :create_upload
  policy :upload_persisted

  transaction do
    model :custom_emoji, :create_custom_emoji
    step :log_creation
  end

  step :clear_cache

  private

  def create_upload(params:, guardian:)
    upload =
      UploadCreator.new(
        params.file.tempfile,
        params.file.original_filename,
        type: "custom_emoji",
      ).create_for(guardian.user.id)

    UploadResult.new(upload:)
  end

  def upload_persisted(upload_result:)
    upload_result.persisted?
  end

  def create_custom_emoji(params:, upload_result:, guardian:)
    CustomEmoji.create(
      name: params.name,
      upload: upload_result.upload,
      group: params.group,
      user: guardian.user,
    )
  end

  def log_creation(params:, guardian:)
    StaffActionLogger.new(guardian.user).log_custom_emoji_create(params.name, group: params.group)
  end

  def clear_cache
    Emoji.clear_cache
  end
end
