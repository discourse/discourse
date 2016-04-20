module Jobs

  class GrantEmoji < Jobs::Onceoff
    def execute_onceoff(args)
      to_award = {}

      Post.secured(Guardian.new)
          .select(:id, :created_at, :cooked, :user_id)
          .visible
          .public_posts
          .where("cooked like '%emoji%'")
          .find_in_batches do |group|
        group.each do |p|
          doc = Nokogiri::HTML::fragment(p.cooked)
          if (doc.css("img.emoji") - doc.css(".quote img")).size > 0
            to_award[p.user_id] ||= { post_id: p.id, created_at: p.created_at }
          end
        end
      end

      badge = Badge.find(Badge::FirstEmoji)
      to_award.each do |user_id, opts|
        BadgeGranter.grant(badge, User.find(user_id), opts)
      end
    end

  end

end
