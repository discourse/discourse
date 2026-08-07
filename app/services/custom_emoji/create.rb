# frozen_string_literal: true

class CustomEmoji::Create
  include Service::Base

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

  model :upload, :create_upload

  transaction do
    model :custom_emoji, :create_custom_emoji
    step :log_creation
  end

  step :clear_cache

  private

  def create_upload(params:, guardian:)
    UploadCreator.new(
      params.file.tempfile,
      params.file.original_filename,
      type: "custom_emoji",
    ).create_for(guardian.user.id)
  end

  def create_custom_emoji(params:, upload:, guardian:)
    CustomEmoji.create(name: params.name, upload:, group: params.group, user: guardian.user)
  end

  def log_creation(params:, guardian:)
    StaffActionLogger.new(guardian.user).log_custom_emoji_create(params.name, group: params.group)
  end

  def clear_cache
    Emoji.clear_cache
  end
end
