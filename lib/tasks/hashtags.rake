# frozen_string_literal: true

desc "Mark posts with the old hashtag cooked format (pre enable_experimental_hashtag_autocomplete) for rebake"
task "hashtags:mark_old_format_for_rebake" => :environment do
  # See Post#rebake_old, which is called via the PeriodicalUpdates job
  # on a schedule.
  puts "Finding posts matching old format, this could take some time..."
  posts_to_rebake = Post.where("cooked like '%class=\"hashtag\"%'")
  puts(
    "[!] You are about to mark #{posts_to_rebake.count} posts containing hashtags in the old format to rebake. [CTRL+c] to cancel, [ENTER] to continue",
  )
  STDIN.gets.chomp if !Rails.env.test?
  posts_to_rebake.update_all(baked_version: 0)
  puts "Done, rebakes will happen when periodical updates job runs."
end
