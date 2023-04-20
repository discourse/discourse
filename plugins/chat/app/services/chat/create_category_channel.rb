# frozen_string_literal: true

module Chat
  # Service responsible for creating a new category chat channel.
  #
  # @example
  #  Service::Chat::CreateCategoryChannel.call(
  #   guardian: guardian,
  #   name: "SuperChannel",
  #   description: "This is the best channel",
  #   slug: "super-channel",
  #   category_id: category.id,
  #  )
  #
  class CreateCategoryChannel
    include Service::Base

    # @!method call(guardian:, **params_to_create)
    #   @param [Guardian] guardian
    #   @param [Hash] params_to_create
    #   @option params_to_create [String] name
    #   @option params_to_create [String] description
    #   @option params_to_create [String] slug
    #   @option params_to_create [Boolean] auto_join_users
    #   @option params_to_create [Integer] category_id
    #   @return [Service::Base::Context]

    policy :can_create_channel
    contract
    model :category, :fetch_category
    policy :category_channel_does_not_exist
    transaction do
      step :create_channel
      step :create_membership
    end
    step :enforce_automatic_channel_memberships

    # @!visibility private
    class Contract
      attribute :name, :string
      attribute :description, :string
      attribute :slug, :string
      attribute :category_id, :integer
      attribute :auto_join_users, :boolean, default: false

      before_validation { self.auto_join_users = auto_join_users.presence || false }

      validates :category_id, presence: true
      validates :name, length: { maximum: SiteSetting.max_topic_title_length }
    end

    private

    def can_create_channel(guardian:, **)
      guardian.can_create_chat_channel?
    end

    def fetch_category(contract:, **)
      Category.find_by(id: contract.category_id)
    end

    def category_channel_does_not_exist(category:, contract:, **)
      !Chat::Channel.exists?(chatable: category, name: contract.name)
    end

    def create_channel(category:, contract:, **)
      channel =
        category.create_chat_channel(
          name: contract.name,
          slug: contract.slug,
          description: contract.description,
          user_count: 1,
          auto_join_users: contract.auto_join_users,
        )
      fail!(channel.errors.full_messages.join("\n")) if channel.errors.present?
      context.merge(channel: channel)
    end

    def create_membership(channel:, guardian:, **)
      membership =
        channel.user_chat_channel_memberships.create(user: guardian.user, following: true)
      fail!(membership.errors.full_messages.join("\n")) if membership.errors.present?
      context.merge(membership: membership)
    end

    def enforce_automatic_channel_memberships(channel:, **)
      return if !channel.auto_join_users?
      Chat::ChannelMembershipManager.new(channel).enforce_automatic_channel_memberships
    end
  end
end
