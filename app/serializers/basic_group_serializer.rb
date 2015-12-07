class BasicGroupSerializer < ApplicationSerializer
  attributes :id,
             :automatic,
             :name,
             :user_count,
             :alias_level,
             :visible,
             :automatic_membership_email_domains,
             :automatic_membership_retroactive,
             :primary_group,
             :title,
             :grant_trust_level,
             :incoming_email

  def include_incoming_email?
    scope.is_staff?
  end
end
