# frozen_string_literal: true

class StylesheetCache < ActiveRecord::Base
  self.table_name = "stylesheet_cache"

  MAX_TO_KEEP = 50
  CLEANUP_AFTER_DAYS = 150

  def self.add(target, digest, content, source_map, max_to_keep: nil)
    max_to_keep ||= MAX_TO_KEEP
    old_logger = ActiveRecord::Base.logger

    return false if where(target: target, digest: digest).exists?

    ActiveRecord::Base.logger = nil if Rails.env.development?

    success = create(target: target, digest: digest, content: content, source_map: source_map)

    count = StylesheetCache.count
    if count > max_to_keep
      remove_lower =
        StylesheetCache.where(target: target).limit(max_to_keep).order("id desc").pluck(:id).last

      DB.exec(<<~SQL, id: remove_lower, target: target)
        DELETE FROM stylesheet_cache
        WHERE id < :id AND target = :target
      SQL
    end

    success
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::ReadOnlyError
    false
  ensure
    ActiveRecord::Base.logger = old_logger if Rails.env.development? && old_logger
  end

  def self.clean_up
    StylesheetCache.where("created_at < ?", CLEANUP_AFTER_DAYS.days.ago).delete_all
  end
end

# == Schema Information
#
# Table name: stylesheet_cache
#
#  id         :integer          not null, primary key
#  target     :string           not null
#  digest     :string           not null
#  content    :string(1000000)  not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  theme_id   :integer          default(-1), not null
#  source_map :string(1500000)
#
# Indexes
#
#  index_stylesheet_cache_on_target_and_digest  (target,digest) UNIQUE
#
