# frozen_string_literal: true

module Jobs

  class GrantEmoji < ::Jobs::Onceoff
    def execute_onceoff(args)
      return unless SiteSetting.enable_badges
      to_award = {}

      Post.secured(Guardian.new)
        .select(:id, :created_at, :cooked, :user_id)
        .visible
        .public_posts
        .where("cooked LIKE '%emoji%'")
        .find_in_batches do |group|
        group.each do |p|
          doc = Nokogiri::HTML::fragment(p.cooked)
          if (doc.css("img.emoji") - doc.css(".quote img")).size > 0
            to_award[p.user_id] ||= { post_id: p.id, created_at: p.created_at }
          end
        end
      end

      to_award.each do |user_id, opts|
        user = User.where(id: user_id).first
        BadgeGranter.grant(badge, user, opts) if user
      end
    end

    def badge
      Badge.find(Badge::FirstEmoji)
    end

  end

end
