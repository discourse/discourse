# frozen_string_literal: true

desc "backfill gamification scores from passed day to today"
task "gamification_scores:backfill_scores_from", [:date] => [:environment] do |_, args|
  date = args[:date]
  if !date
    puts "ERROR: Expecting rake gamification_scores:backfill_scores_from[2021-04-01]"
    exit 1
  end

  DiscourseGamification::GamificationScore.calculate_scores(since_date: date)
  puts "Scores updated"
end
