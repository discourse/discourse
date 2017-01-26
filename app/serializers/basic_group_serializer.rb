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
             :incoming_email,
             :has_messages,
             :flair_url,
             :flair_bg_color,
             :flair_color,
             :bio_raw,
             :bio_cooked,
             :public,
             :allow_membership_requests,
             :full_name

  def include_incoming_email?
    staff?
  end

  def include_has_messsages
    staff?
  end

  def include_bio_raw
    staff?
  end

  private

  def staff?
    @staff ||= scope.is_staff?
  end
end
