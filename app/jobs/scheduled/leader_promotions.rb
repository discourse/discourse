module Jobs

  class LeaderPromotions < Jobs::Scheduled
    daily at: 4.hours

    def execute(args)
      # Demotions
      demoted_user_ids = []
      User.real.where(trust_level: TrustLevel[3]).find_each do |u|
        # Don't demote too soon after being promoted
        next if UserHistory.for(u, :auto_trust_level_change)
                           .where('created_at >= ?', SiteSetting.tl3_promotion_min_duration.to_i.days.ago)
                           .where(previous_value: TrustLevel[2].to_s)
                           .where(new_value: TrustLevel[3].to_s)
                           .exists?

        if Promotion.tl3_lost?(u)
          demoted_user_ids << u.id
          Promotion.new(u).change_trust_level!(TrustLevel[2])
        end
      end

      # Promotions
      User.real.where(trust_level: TrustLevel[2]).where.not(id: demoted_user_ids).find_each do |u|
        Promotion.new(u).review_tl2
      end
    end
  end

end
