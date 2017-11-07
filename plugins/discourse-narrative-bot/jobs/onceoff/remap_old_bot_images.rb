module Jobs
  module DiscourseNarrativeBot
    class RemapOldBotImages < ::Jobs::Onceoff
      def execute_onceoff(args)
        paths = [
          "/images/font-awesome-link.png",
          "/images/unicorn.png",
          "/images/font-awesome-ellipsis.png",
          "/images/font-awesome-bookmark.png",
          "/images/font-awesome-smile.png",
          "/images/font-awesome-flag.png",
          "/images/font-awesome-search.png",
          "/images/capybara-eating.gif",
          "/images/font-awesome-pencil.png",
          "/images/font-awesome-trash.png",
          "/images/font-awesome-rotate-left.png",
          "/images/font-awesome-gear.png",
        ]

        Post.raw_match("/images/").where(user_id: -2).find_each do |post|
          if (matches = post.raw.scan(/(?<!\/plugins\/discourse-narrative-bot)(#{paths.join("|")})/)).present?
            new_raw = post.raw

            matches.each do |match|
              path = match.first
              new_raw = new_raw.gsub(path, "/plugins/discourse-narrative-bot#{path}")
            end

            post.update_columns(raw: new_raw)
            post.rebake!
          end
        end
      end
    end
  end
end
