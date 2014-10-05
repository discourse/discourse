# THIS WILL MOVE TO A PLUGIN WHEN READY
#
# The idea is to gamify pull requests, assign badges to people who
# make the most pull requests
#
# 1 PR accepted - contributor badge
# 25 PRs accepted - great contributor badge
# 250 PRs accepted - amazing contributor badge

require File.expand_path("../../config/environment", __FILE__)

# ensure badges exist
unless bronze = Badge.find_by(name: 'contributor')
  bronze = Badge.create!(name: 'contributor',
                         description: 'contributed an accepted pull request',
                         badge_type_id: 3)
end

unless silver = Badge.find_by(name: 'great contributor')
  silver = Badge.create!(name: 'great contributor',
                         description: 'contributed 25 accepted pull request',
                         badge_type_id: 2)
end

unless gold = Badge.find_by(name: 'amazing contributor')
  gold = Badge.create!(name: 'amazing contributor',
                         description: 'contributed 250 accepted pull request',
                         badge_type_id: 1)
end

emails = []
`git log --merges --pretty=format:%p --grep='Merge pull request'`.each_line do |m|
  emails << (`git log -1 --format=%ce #{m.split(' ')[1].strip}`.strip)
end

email_commits = emails.group_by{|e| e}.map{|k, l|[k,l.count]}


email_commits.each do |email, commits|
  user = User.find_by(email: email)

  if user
    if commits < 25
      BadgeGranter.grant(bronze, user)
    elsif commits < 250
      BadgeGranter.grant(silver, user)
      if user.title.blank?
        user.title = silver.name
        user.save
      end
    else
      BadgeGranter.grant(gold, user)
      if user.title.blank?
        user.title = gold.name
        user.save
      end
    end
  end

end

