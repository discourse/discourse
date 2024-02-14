# frozen_string_literal: true

class PostMention < ActiveRecord::Base
  belongs_to :post
  belongs_to :mention, polymorphic: true

  def self.ensure_exist!(post_id:, mentions: [], ids_by_type: {})
    if mentions.present? && ids_by_type.blank?
      ids_by_type = {}
      mentions.each { |mention| (ids_by_type[mention.class.name] ||= []) << mention.id }
    end

    rows =
      ids_by_type
        .map do |mention_type, mention_ids|
          mention_ids.map do |mention_id|
            {
              post_id: post_id,
              mention_type: mention_type,
              mention_id: mention_id,
              created_at: Time.zone.now,
              updated_at: Time.zone.now,
            }
          end
        end
        .flatten

    PostMention.transaction do |transaction|
      PostMention.where(post_id: post_id).delete_all
      PostMention.insert_all(rows) if rows.present?
    end
  end
end

# == Schema Information
#
# Table name: post_mentions
#
#  id           :bigint           not null, primary key
#  post_id      :bigint           not null
#  mention_type :string           not null
#  mention_id   :bigint           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_post_mentions_on_mention           (mention_type,mention_id)
#  index_post_mentions_on_post_and_mention  (post_id,mention_type,mention_id) UNIQUE
#  index_post_mentions_on_post_id           (post_id)
#
