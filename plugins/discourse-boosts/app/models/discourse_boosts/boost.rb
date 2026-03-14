# frozen_string_literal: true

module DiscourseBoosts
  class Boost < ActiveRecord::Base
    self.table_name = "discourse_boosts"

    def self.polymorphic_class_mapping = { "Boost" => DiscourseBoosts::Boost }
    def self.polymorphic_name = polymorphic_class_mapping.invert[self] || super

    belongs_to :post
    belongs_to :user

    MAX_VISIBLE_LENGTH = 16
    MAX_EMOJI = 5

    validates :post_id, uniqueness: { scope: :user_id }
    validates :raw, presence: true, length: { maximum: 1000 }
    validate :raw_visible_length
    validate :raw_emoji_count

    def raw_visible_length
      return if raw.blank?

      visible =
        normalized_raw.gsub(/:[a-z0-9_+-]+(?::t\d)?:/) do |match|
          Emoji.exists?(match[1..-2].sub(/:t\d$/, "")) ? "x" : match
        end

      if visible.length > MAX_VISIBLE_LENGTH
        errors.add(:raw, I18n.t("discourse_boosts.boost_too_long", count: MAX_VISIBLE_LENGTH))
      end
    end

    def raw_emoji_count
      return if raw.blank?

      count =
        normalized_raw
          .scan(/:[a-z0-9_+-]+(?::t\d)?:/)
          .count { |match| Emoji.exists?(match[1..-2].sub(/:t\d$/, "")) }

      if count > MAX_EMOJI
        errors.add(:raw, I18n.t("discourse_boosts.too_many_emoji", count: MAX_EMOJI))
      end
    end

    def normalized_raw
      @normalized_raw ||= Emoji.unicode_unescape(raw)
    end

    validates :cooked, presence: true

    before_validation :clean_raw, if: :will_save_change_to_raw?
    before_validation :cook_raw, if: :will_save_change_to_raw?
    after_destroy :delete_notifications

    MARKDOWN_FEATURES = %w[emoji]
    MARKDOWN_IT_RULES = []

    def self.publish_add(post, boost)
      message = {
        id: post.id,
        type: :boost_added,
        boost: {
          id: boost.id,
          cooked: boost.cooked,
          user: BasicUserSerializer.new(boost.user, root: false).as_json,
        },
      }
      post.publish_message!("/topic/#{post.topic_id}", message)
    end

    def self.publish_remove(post, boost_id)
      message = { id: post.id, type: :boost_removed, boost_id: boost_id }
      post.publish_message!("/topic/#{post.topic_id}", message)
    end

    def self.cook(raw)
      PrettyText.cook(
        raw.to_s.strip,
        features_override: MARKDOWN_FEATURES,
        markdown_it_rules: MARKDOWN_IT_RULES,
      )
    end

    private

    def delete_notifications
      boost_notifications =
        Notification.where(
          user_id: post.user_id,
          topic_id: post.topic_id,
          post_number: post.post_number,
          notification_type: Notification.types[:boost],
        )

      boost_notifications
        .where("data::json ->> 'display_username' = ?", user.username)
        .where("data::json ->> 'username2' IS NULL AND data::json ->> 'consolidated' IS NULL")
        .destroy_all

      update_consolidated_notification(boost_notifications)
    end

    def update_consolidated_notification(boost_notifications)
      notification =
        boost_notifications
          .where("data::json ->> 'username2' IS NOT NULL")
          .where("data::json ->> 'consolidated' IS NULL")
          .first
      return unless notification

      data = notification.data_hash
      unique_usernames =
        (data[:unique_usernames] || [data[:display_username], data[:username2]]).map(&:to_s)
      return if unique_usernames.exclude?(user.username)

      remaining_usernames = unique_usernames - [user.username]

      case remaining_usernames.size
      when 0
        notification.destroy!
      when 1
        remaining_user = User.find_by(username: remaining_usernames.first)
        remaining_boost =
          DiscourseBoosts::Boost.find_by(post_id: post.id, user_id: remaining_user&.id)
        notification.update!(
          data: {
            display_username: remaining_usernames.first,
            display_name: remaining_user&.name,
            boost_raw: remaining_boost&.raw,
            topic_title: data[:topic_title],
          }.to_json,
        )
      else
        new_display_user = User.find_by(username: remaining_usernames.last)
        new_username2_user = User.find_by(username: remaining_usernames[-2])
        notification.update!(
          data:
            data.merge(
              display_username: remaining_usernames.last,
              display_name: new_display_user&.name,
              username2: remaining_usernames[-2],
              name2: new_username2_user&.name,
              count: remaining_usernames.size,
              unique_usernames: remaining_usernames,
            ).to_json,
        )
      end
    end

    def clean_raw
      self.raw = TextCleaner.clean(raw, strip_whitespaces: true, strip_zero_width_spaces: true)
    end

    def cook_raw
      self.cooked = self.class.cook(self.raw)
    end
  end
end
