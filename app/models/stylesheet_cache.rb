class StylesheetCache < ActiveRecord::Base
  self.table_name = 'stylesheet_cache'

  MAX_TO_KEEP = 50

  def self.add(target,digest,content)

    return false if where(target: target, digest: digest).exists?

    success = create(target: target, digest: digest, content: content)

    count = StylesheetCache.count
    if count > MAX_TO_KEEP

      remove_lower = StylesheetCache
                     .where(target: target)
                     .limit(MAX_TO_KEEP)
                     .order('id desc')
                     .pluck(:id)
                     .last

      exec_sql("DELETE FROM stylesheet_cache where id < :id", id: remove_lower)
    end

    success
  rescue ActiveRecord::RecordNotUnique
    false
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
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_stylesheet_cache_on_target_and_digest  (target,digest) UNIQUE
#
