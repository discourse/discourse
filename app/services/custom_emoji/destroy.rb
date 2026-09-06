# frozen_string_literal: true

class CustomEmoji::Destroy
  include Service::Base

  params do
    attribute :name, :string

    validates :name, presence: true
  end

  model :custom_emoji, optional: true

  only_if :custom_emoji_exists do
    transaction do
      step :log_destruction
      step :remove_custom_emoji
    end
  end

  step :clear_cache
  step :rebake_affected_posts

  private

  def fetch_custom_emoji(params:)
    CustomEmoji.find_by(name: params.name)
  end

  def custom_emoji_exists(custom_emoji:)
    custom_emoji.present?
  end

  def log_destruction(params:, guardian:)
    StaffActionLogger.new(guardian.user).log_custom_emoji_destroy(params.name)
  end

  def remove_custom_emoji(custom_emoji:)
    # The clean_up_uploads job removes the upload after it becomes unused.
    custom_emoji.destroy!
  end

  def clear_cache
    Emoji.clear_cache
  end

  def rebake_affected_posts(params:)
    Jobs.enqueue(:rebake_custom_emoji_posts, name: params.name)
  end
end
