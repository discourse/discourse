# frozen_string_literal: true

class Appreciations::List
  include Service::Base

  PAGE_SIZE = 20

  params do
    attribute :username, :string
    attribute :before, :datetime
    attribute :direction, :string
    attribute :types, :string

    validates :username, presence: true
    validates :direction, presence: true, inclusion: { in: %w[given received] }
  end

  model :target_user
  policy :can_see
  model :appreciations, optional: true

  private

  def fetch_target_user(params:, guardian:)
    username_lower = params.username.downcase

    return guardian.user if guardian.user&.username_lower == username_lower

    scope = User.where(username_lower:)
    scope = scope.where(active: true) unless guardian.user&.staff?
    scope.first
  end

  def can_see(params:, guardian:, target_user:)
    if params.direction == "received"
      guardian.can_see_notifications?(target_user)
    else
      guardian.can_see_profile?(target_user)
    end
  end

  def fetch_appreciations(params:, guardian:, target_user:)
    before = params.before || Time.current
    enabled_types = parse_types(params.types)

    items = []

    providers.each do |provider|
      next unless provider.enabled?
      next unless enabled_types.nil? || enabled_types.include?(provider.type)

      fetched =
        if params.direction == "given"
          provider.fetch_given(user: target_user, before:, limit: PAGE_SIZE, guardian:)
        else
          provider.fetch_received(user: target_user, before:, limit: PAGE_SIZE, guardian:)
        end

      items.concat(fetched)
    end

    items.sort_by(&:created_at).reverse.first(PAGE_SIZE)
  end

  def providers
    [likes_provider] + DiscoursePluginRegistry.appreciation_providers
  end

  def likes_provider
    @likes_provider ||= AppreciationProviders::Likes.new
  end

  def parse_types(types)
    return nil if types.blank?
    types.split(",").map(&:strip)
  end
end
