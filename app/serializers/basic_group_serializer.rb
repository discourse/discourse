class BasicGroupSerializer < ApplicationSerializer
  attributes :id,
             :automatic,
             :name,
             :user_count,
             :alias_level,
             :visible,
             :automatic_membership_email_domains,
             :automatic_membership_retroactive

  def automatic_membership_email_domains
    object.automatic_membership_email_domains.presence || ""
  end
end
