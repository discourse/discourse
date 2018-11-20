module Jobs

  class GrantFirstReplyByEmail < Jobs::Onceoff

    def execute_onceoff(args)
      return unless SiteSetting.enable_badges
      to_award = {}

      Post.select(:id, :created_at, :user_id)
        .secured(Guardian.new)
        .visible
        .public_posts
        .where(via_email: true)
        .where("post_number > 1")
        .find_in_batches do |group|
        group.each do |p|
          to_award[p.user_id] ||= { post_id: p.id, created_at: p.created_at }
        end
      end

      to_award.each do |user_id, opts|
        user = User.where(id: user_id).first
        BadgeGranter.grant(badge, user, opts) if user
      end
    end

    def badge
      Badge.find(Badge::FirstReplyByEmail)
    end

  end

end
