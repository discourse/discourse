# frozen_string_literal: true

desc "Copy discussion posts' current HTML into their published articles, after rebaking them"
task "blog:refresh_articles" => :environment do
  refreshed =
    Blog::Publication
      .where.not(published_revision_id: nil)
      .includes(discussion_topic: %i[first_post image_upload])
      .find_each
      .count(&:refresh_article!)
  puts "Refreshed #{refreshed} published #{"article".pluralize(refreshed)}."
end
