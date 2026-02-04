# frozen_string_literal: true

class Groups::Create
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [String] :name
  #   @option params [Integer] :mentionable_level
  #   @option params [Integer] :messageable_level
  #   @option params [Integer] :visibility_level
  #   @option params [Integer] :members_visibility_level
  #   @option params [String] :automatic_membership_email_domains
  #   @option params [String] :title
  #   @option params [Boolean] :primary_group
  #   @option params [Integer] :grant_trust_level
  #   @option params [String] :incoming_email
  #   @option params [String] :flair_icon
  #   @option params [Integer] :flair_upload_id
  #   @option params [String] :flair_bg_color
  #   @option params [String] :flair_color
  #   @option params [String] :bio_raw
  #   @option params [Boolean] :public_admission
  #   @option params [Boolean] :public_exit
  #   @option params [Boolean] :allow_membership_requests
  #   @option params [String] :full_name
  #   @option params [Integer] :default_notification_level
  #   @option params [String] :membership_request_template
  #   @option params [String] :owner_usernames
  #   @option params [String] :usernames
  #   @option params [Boolean] :publish_read_state
  #   @option params [Hash] :custom_fields
  #   @option params [Hash] :plugin_group_params
  #   @option params [Array] :associated_group_ids

  params do
    attribute :name, :string
    attribute :mentionable_level, :integer, default: Group::ALIAS_LEVELS[:nobody]
    attribute :messageable_level, :integer, default: Group::ALIAS_LEVELS[:nobody]
    attribute :visibility_level, :integer, default: Group.visibility_levels[:public]
    attribute :members_visibility_level, :integer, default: Group.visibility_levels[:public]
    attribute :automatic_membership_email_domains, :string
    attribute :title, :string
    attribute :primary_group, :boolean, default: false
    attribute :grant_trust_level, :integer
    attribute :incoming_email, :string
    attribute :flair_icon, :string
    attribute :flair_upload_id, :integer
    attribute :flair_bg_color, :string
    attribute :flair_color, :string
    attribute :bio_raw, :string
    attribute :public_admission, :boolean, default: false
    attribute :public_exit, :boolean, default: false
    attribute :allow_membership_requests, :boolean, default: false
    attribute :full_name, :string
    attribute :default_notification_level,
              :integer,
              default: GroupUser.notification_levels[:watching]

    attribute :membership_request_template, :string
    attribute :owner_usernames, :string
    attribute :usernames, :string
    attribute :publish_read_state, :boolean, default: false
    attribute :custom_fields, :hash, default: {}
    attribute :plugin_group_params, :hash, default: {}
    attribute :associated_group_ids, :array

    validates :name, presence: true
    validates :default_notification_level, inclusion: { in: GroupUser.notification_levels.values }
    validates :mentionable_level, inclusion: { in: Group::ALIAS_LEVELS.values }
    validates :messageable_level, inclusion: { in: Group::ALIAS_LEVELS.values }
    validates :visibility_level,
              inclusion: {
                in: Group.visibility_levels.values,
              },
              allow_blank: true
    validates :members_visibility_level,
              inclusion: {
                in: Group.visibility_levels.values,
              },
              allow_blank: true

    validate :custom_fields_allowed_keys

    def custom_fields_allowed_keys
      return if custom_fields.blank?

      allowed_keys = DiscoursePluginRegistry.editable_group_custom_fields
      return if allowed_keys.blank?

      invalid_keys = custom_fields.keys.map(&:to_sym) - allowed_keys.map(&:to_sym)
      return if invalid_keys.empty?

      invalid_keys.each { |key| errors.add(:custom_fields, "contains disallowed key: #{key}") }
    end
  end

  policy :can_create_group
  model :group
  step :save_group
  step :log_group_histories

  private

  def can_create_group(guardian:)
    guardian.can_create_group?
  end

  def fetch_group(params:, guardian:)
    # We don't know the plugin group params ahead of time when calling Create,
    # so we have them in a nested key and hoist them out here.
    params_hash = params.to_hash.except(:owner_usernames, :usernames, :plugin_group_params)
    params_hash.merge!(params.plugin_group_params.to_hash)

    params_hash[:associated_group_ids] = [] if params.associated_group_ids.present? &&
      !guardian.can_associate_groups?

    Group.new(params_hash) do |group|
      group.membership_request_template = nil unless params.allow_membership_requests

      if params.owner_usernames.present?
        owner_ids = User.where(username: params.owner_usernames.split(",")).pluck(:id)
        owner_ids.each { |user_id| group.group_users.build(user_id: user_id, owner: true) }
      end

      if params.usernames.present?
        user_ids = User.where(username: params.usernames.split(",")).pluck(:id)
        user_ids -= owner_ids if owner_ids
        user_ids.each { |user_id| group.group_users.build(user_id: user_id) }
      end
    end
  end

  def save_group(guardian:, params:, group:)
    group.save!
    group.restore_user_count!
  end

  def log_group_histories(guardian:, group:)
    GroupHistory.transaction do
      group_action_logger = GroupActionLogger.new(guardian.user, group)
      group.group_users.each do |group_user|
        group_action_logger.log_make_user_group_owner(group_user.user) if group_user.owner?
        group_action_logger.log_add_user_to_group(group_user.user)
      end
    end
  end
end
