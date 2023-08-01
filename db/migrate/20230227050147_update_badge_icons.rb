# frozen_string_literal: true

class UpdateBadgeIcons < ActiveRecord::Migration[7.0]
  def change
    icon_id_replacement = [
      ["book-reader", [Badge::Reader], "fa-certificate"],
      ["file-alt", [Badge::ReadGuidelines], "fa-certificate"],
      [
        "link",
        [Badge::FirstLink, Badge::PopularLink, Badge::HotLink, Badge::FamousLink],
        "fa-certificate",
      ],
      ["quote-right", [Badge::FirstQuote], "fa-certificate"],
      ["heart", [Badge::FirstLike, Badge::Welcome], "fa-certificate"],
      ["flag", [Badge::FirstFlag], "fa-certificate"],
      [
        "share-alt",
        [Badge::FirstShare, Badge::NiceShare, Badge::GoodShare, Badge::GreatShare],
        "fa-certificate",
      ],
      ["user-edit", [Badge::Autobiographer], "fa-certificate"],
      ["pen", [Badge::Editor], "fa-certificate"],
      ["far-edit", [Badge::WikiEditor], "fa-certificate"],
      ["reply", [Badge::NicePost, Badge::GoodPost, Badge::GreatPost], "fa-certificate"],
      ["file-signature", [Badge::NiceTopic, Badge::GoodTopic, Badge::GreatTopic], "fa-certificate"],
      ["at", [Badge::FirstMention], "fa-certificate"],
      ["smile", [Badge::FirstEmoji], "fa-certificate"],
      ["cube", [Badge::FirstOnebox], "fa-certificate"],
      ["envelope", [Badge::FirstReplyByEmail], "fa-certificate"],
      ["medal", [Badge::NewUserOfTheMonth], "fa-certificate"],
      ["birthday-cake", [Badge::Anniversary], "far-clock"],
    ]

    icon_id_replacement.each do |new_icon, badge_ids, old_icon|
      execute "UPDATE badges SET icon = '#{new_icon}' WHERE id IN (#{badge_ids.join(",")}) AND icon = '#{old_icon}'"
    end
  end
end
