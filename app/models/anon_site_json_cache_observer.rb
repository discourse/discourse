class AnonSiteJsonCacheObserver < ActiveRecord::Observer
  observe :category, :post_action_type, :user_field, :group

  def after_destroy(object)
    Site.clear_anon_cache!
  end

  def after_save(object)
    Site.clear_anon_cache!
  end

end
