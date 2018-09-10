class StylesheetCache < ActiveRecord::Base
  self.table_name = 'stylesheet_cache'

  MAX_TO_KEEP = 50

  def self.add(target, digest, content, source_map)
    old_logger = ActiveRecord::Base.logger

    return false if where(target: target, digest: digest).exists?

    if Rails.env.development?
      ActiveRecord::Base.logger = nil
    end

    success = create(target: target, digest: digest, content: content, source_map: source_map)

    count = StylesheetCache.count
    if count > MAX_TO_KEEP

      remove_lower = StylesheetCache
        .where(target: target)
        .limit(MAX_TO_KEEP)
        .order('id desc')
        .pluck(:id)
        .last

      DB.exec("DELETE FROM stylesheet_cache where id < :id", id: remove_lower)
    end

    success
  rescue ActiveRecord::RecordNotUnique
    false
  ensure
    if Rails.env.development? && old_logger
      ActiveRecord::Base.logger = old_logger
    end
  end

end

# == Schema Information
#
# Table name: stylesheet_cache
#
#  id         :integer          not null, primary key
#  target     :string           not null
#  digest     :string           not null
#  content    :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  theme_id   :integer          default(-1), not null
#  source_map :text
#
# Indexes
#
#  index_stylesheet_cache_on_target_and_digest  (target,digest) UNIQUE
#
