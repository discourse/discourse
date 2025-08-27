# frozen_string_literal: true

desc "Backfill sentiment for all posts"
task "ai:sentiment:backfill", [:start_post] => [:environment] do |_, args|
  DiscourseAi::Sentiment::PostClassification
    .backfill_query(from_post_id: args[:start_post].to_i)
    .find_in_batches do |batch|
      print "."
      DiscourseAi::Sentiment::PostClassification.new.bulk_classify!(batch)
    end
end
