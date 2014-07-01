module Jobs

  class LeaderPromotions < Jobs::Scheduled
    daily at: 4.hours

    def execute(args)
      # Demotions
      demoted_user_ids = []
      User.real.where(trust_level: TrustLevel.levels[:leader]).find_each do |u|
        unless Promotion.leader_met?(u)
          demoted_user_ids << u.id
          Promotion.new(u).change_trust_level!(:regular)
        end
      end

      # Promotions
      User.real.where(trust_level: TrustLevel.levels[:regular]).where.not(id: demoted_user_ids).find_each do |u|
        Promotion.new(u).review_regular
      end
    end
  end

end
