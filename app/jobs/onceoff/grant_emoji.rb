module Jobs

  class GrantEmoji < Jobs::Onceoff

    def execute_onceoff(args)
      to_award = {}

      Post.secured(Guardian.new).visible.public_posts.find_in_batches(batch_size: 5000) do |group|
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
