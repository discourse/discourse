class PageObserver < ActiveRecord::Observer
  def reload_routes(page)
    Rails.application.reload_routes!
  end
  alias_method :after_save,    :reload_routes
  alias_method :after_destroy, :reload_routes
end

