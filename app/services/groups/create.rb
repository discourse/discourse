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
  #   @option params [Array] :associated_group_ids

  options { attribute :dynamic_attributes, default: -> { {} } }

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
    attribute :owner_usernames, :array, default: -> { [] }
    attribute :usernames, :array, default: -> { [] }
    attribute :publish_read_state, :boolean, default: false
    attribute :custom_fields, default: -> { {} }
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

    after_validation { self.membership_request_template = nil unless allow_membership_requests }

    def owner_ids
      return [] if owner_usernames.blank?
      User.where(username: owner_usernames).pluck(:id)
    end

    def user_ids
      return [] if usernames.blank?
      User.where(username: usernames).pluck(:id) - owner_ids
    end

    private

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
  model :user_attributes, :build_user_attributes, optional: true
  model :group, :instantiate_group
  only_if(:should_associate_groups) { step :associate_groups }

  transaction do
    step :save
    step :log_group_histories
  end

  private

  def can_create_group(guardian:)
    guardian.can_create_group?
  end

  def build_user_attributes(params:)
    params.owner_ids.map { { user_id: _1, owner: true } } + params.user_ids.map { { user_id: _1 } }
  end

  def instantiate_group(params:, guardian:, user_attributes:, options:)
    Group.new(
      params.except(:owner_usernames, :usernames, :associated_group_ids).merge(
        options.dynamic_attributes,
      ),
    ) { _1.group_users.build(user_attributes) }
  end

  def should_associate_groups(guardian:, params:)
    guardian.can_associate_groups? && params.associated_group_ids.present?
  end

  def associate_groups(group:, params:)
    group.associated_group_ids = params.associated_group_ids
  end

  def save(group:)
    group.save!
    group.restore_user_count!
  end

  def log_group_histories(guardian:, group:)
    GroupActionLogger.new(guardian.user, group).log_group_creation
  end
end
