# frozen_string_literal: true

class UpdateBadgeIcons < ActiveRecord::Migration[7.0]
  def change
    unedited = "AND icon = 'fa-certificate'"

    execute "UPDATE badges SET icon = 'book-reader' WHERE id = '#{Badge::Reader}' #{unedited}"
    execute "UPDATE badges SET icon = 'file-alt' WHERE id = '#{Badge::ReadGuidelines}' #{unedited}"
    execute "UPDATE badges SET icon = 'link' WHERE id IN (#{
              [Badge::FirstLink, Badge::PopularLink, Badge::HotLink, Badge::FamousLink].join(",")
            }) #{unedited}"
    execute "UPDATE badges SET icon = 'quote-right' WHERE id = '#{Badge::FirstQuote}' #{unedited}"
    execute "UPDATE badges SET icon = 'heart' WHERE id IN (#{[Badge::FirstLike, Badge::Welcome].join(",")}) #{unedited}"
    execute "UPDATE badges SET icon = 'flag' WHERE id = '#{Badge::FirstFlag}' #{unedited}"
    execute "UPDATE badges SET icon = 'share-alt' WHERE id IN (#{
              [Badge::FirstShare, Badge::NiceShare, Badge::GoodShare, Badge::GreatShare].join(",")
            }) #{unedited}"
    execute "UPDATE badges SET icon = 'user-edit' WHERE id = '#{Badge::Autobiographer}' #{unedited}"
    execute "UPDATE badges SET icon = 'pen' WHERE id IN (#{[Badge::Editor, Badge::WikiEditor].join(",")}) #{unedited}"
    execute "UPDATE badges SET icon = 'reply' WHERE id IN (#{
              [Badge::NicePost, Badge::GoodPost, Badge::GreatPost].join(",")
            }) #{unedited}"
    execute "UPDATE badges SET icon = 'file-signature' WHERE id IN (#{
              [Badge::NiceTopic, Badge::GoodTopic, Badge::GreatTopic].join(",")
            }) #{unedited}"
    execute "UPDATE badges SET icon = 'birthday-cake' WHERE id = '#{Badge::Anniversary}'" # far-clock
    execute "UPDATE badges SET icon = 'at' WHERE id = '#{Badge::FirstMention}' #{unedited}"
    execute "UPDATE badges SET icon = 'smile' WHERE id = '#{Badge::FirstEmoji}' #{unedited}"
    execute "UPDATE badges SET icon = 'cube' WHERE id = '#{Badge::FirstOnebox}' #{unedited}"
    execute "UPDATE badges SET icon = 'envelope' WHERE id = '#{Badge::FirstReplyByEmail}' #{unedited}"
    execute "UPDATE badges SET icon = 'medal' WHERE id = '#{Badge::NewUserOfTheMonth}' #{unedited}"
  end
end
