class StylesheetCache < ActiveRecord::Base
  self.table_name = 'stylesheet_cache'

  MAX_TO_KEEP = 10

  def self.add(target,digest,content)
    success = create(target: target, digest: digest, content: content)

    count = StylesheetCache.count
    if count > MAX_TO_KEEP

      remove_lower = StylesheetCache.limit(MAX_TO_KEEP)
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
