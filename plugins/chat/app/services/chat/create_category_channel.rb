# frozen_string_literal: true

module Chat
  # Service responsible for creating a new category chat channel.
  #
  # @example
  #  Service::Chat::CreateCategoryChannel.call(
  #   guardian: guardian,
  #   params: {
  #     name: "SuperChannel",
  #     description: "This is the best channel",
  #     slug: "super-channel",
  #     category_id: category.id,
  #     threading_enabled: true,
  #   }
  #  )
  #
  class CreateCategoryChannel
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [String] :name
    #   @option params [String] :description
    #   @option params [String] :slug
    #   @option params [Boolean] :auto_join_users
    #   @option params [Integer] :category_id
    #   @option params [Boolean] :threading_enabled
    #   @return [Service::Base::Context]

    policy :public_channels_enabled
    policy :can_create_channel
    params do
      attribute :name, :string
      attribute :description, :string
      attribute :slug, :string
      attribute :category_id, :integer
      attribute :auto_join_users, :boolean, default: false
      attribute :threading_enabled, :boolean, default: false

      before_validation do
        self.auto_join_users = auto_join_users.presence || false
        self.threading_enabled = threading_enabled.presence || false
      end

      validates :category_id, presence: true
      validates :name, length: { maximum: SiteSetting.max_topic_title_length }
    end
    model :category
    policy :category_channel_does_not_exist
    transaction do
      model :channel, :create_channel
      model :membership, :create_membership
    end
    step :enforce_automatic_channel_memberships

    private

    def public_channels_enabled
      SiteSetting.enable_public_channels
    end

    def can_create_channel(guardian:)
      guardian.can_create_chat_channel?
    end

    def fetch_category(params:)
      Category.find_by(id: params.category_id)
    end

    def category_channel_does_not_exist(category:, params:)
      !Chat::Channel.exists?(chatable: category, name: params.name)
    end

    def create_channel(category:, params:)
      category.create_chat_channel(
        user_count: 1,
        **params.slice(:name, :slug, :description, :auto_join_users, :threading_enabled),
      )
    end

    def create_membership(channel:, guardian:)
      channel.user_chat_channel_memberships.create(user: guardian.user, following: true)
    end

    def enforce_automatic_channel_memberships(channel:)
      return if !channel.auto_join_users?
      Chat::ChannelMembershipManager.new(channel).enforce_automatic_channel_memberships
    end
  end
end
