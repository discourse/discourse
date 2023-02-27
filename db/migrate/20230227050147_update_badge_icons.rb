# frozen_string_literal: true

class UpdateBadgeIcons < ActiveRecord::Migration[7.0]
  def change
    execute "UPDATE badges SET icon = 'book-reader' WHERE id = '#{Badge::Reader}'"
    execute "UPDATE badges SET icon = 'file-alt' WHERE id = '#{Badge::ReadGuidelines}'"
    execute "UPDATE badges SET icon = 'link' WHERE id IN (#{
              [Badge::FirstLink, Badge::PopularLink, Badge::HotLink, Badge::FamousLink].join(",")
            })"
    execute "UPDATE badges SET icon = 'quote-right' WHERE id = '#{Badge::FirstQuote}'"
    execute "UPDATE badges SET icon = 'heart' WHERE id IN (#{[Badge::FirstLike, Badge::Welcome].join(",")})"
    execute "UPDATE badges SET icon = 'flag' WHERE id = '#{Badge::FirstFlag}'"
    execute "UPDATE badges SET icon = 'share-alt' WHERE id IN (#{
              [Badge::FirstShare, Badge::NiceShare, Badge::GoodShare, Badge::GreatShare].join(",")
            })"
    execute "UPDATE badges SET icon = 'user-edit' WHERE id = '#{Badge::Autobiographer}'"
    execute "UPDATE badges SET icon = 'pen' WHERE id IN (#{[Badge::Editor, Badge::WikiEditor].join(",")})"
    execute "UPDATE badges SET icon = 'reply' WHERE id IN (#{
              [Badge::NicePost, Badge::GoodPost, Badge::GreatPost].join(",")
            })"
    execute "UPDATE badges SET icon = 'file-signature' WHERE id IN (#{
              [Badge::NiceTopic, Badge::GoodTopic, Badge::GreatTopic].join(",")
            })"
    execute "UPDATE badges SET icon = 'birthday-cake' WHERE id = '#{Badge::Anniversary}'"
    execute "UPDATE badges SET icon = 'at' WHERE id = '#{Badge::FirstMention}'"
    execute "UPDATE badges SET icon = 'smile' WHERE id = '#{Badge::FirstEmoji}'"
    execute "UPDATE badges SET icon = 'cube' WHERE id = '#{Badge::FirstOnebox}'"
    execute "UPDATE badges SET icon = 'envelope' WHERE id = '#{Badge::FirstReplyByEmail}'"
    execute "UPDATE badges SET icon = 'medal' WHERE id = '#{Badge::NewUserOfTheMonth}'"
  end
end
