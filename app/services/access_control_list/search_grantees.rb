# frozen_string_literal: true

class AccessControlList::SearchGrantees
  include Service::Base

  MAX_RESULTS = 50

  params do
    attribute :term, :string
    attribute :limit, :integer

    validates :limit,
              presence: true,
              numericality: {
                only_integer: true,
                greater_than: 0,
                less_than_or_equal_to: AccessControlList::SearchGrantees::MAX_RESULTS,
              }
  end

  model :search_term, optional: true
  model :visible_groups, optional: true
  model :users, optional: true
  model :groups, optional: true

  private

  def fetch_search_term(params:)
    params.term.to_s.strip.presence
  end

  def fetch_visible_groups(guardian:)
    Group.visible_groups(
      guardian.user,
      "groups.name ASC",
      include_everyone: !SiteSetting.granular_anonymous_and_logged_in_groups_permissions,
      include_pseudogroups: SiteSetting.granular_anonymous_and_logged_in_groups_permissions,
    )
  end

  def fetch_users(search_term:, params:, guardian:)
    if search_term.present?
      UserSearch.new(search_term, searching_user: guardian.user, limit: params.limit).search
    else
      []
    end
  end

  def fetch_groups(search_term:, visible_groups:, params:)
    if search_term.present?
      Group.search_groups(search_term, groups: visible_groups, sort: :auto).limit(params.limit)
    else
      []
    end
  end
end
