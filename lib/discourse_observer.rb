#
# Support delegating after_create to an appropriate helper for that class name.
# For example, an observer on post will call after_create_post if that method
# is defined.
#
# It does this after_commit by default, and contains a hack to make this work
# even in test mode.
#
class DiscourseObserver < ActiveRecord::Observer

  def after_create_delegator(model)
    observer_method = :"after_create_#{model.class.name.underscore}"
    send(observer_method, model) if respond_to?(observer_method)
  end

  def after_destroy_delegator(model)
    observer_method = :"after_destroy_#{model.class.name.underscore}"
    send(observer_method, model) if respond_to?(observer_method)
  end

end

if Rails.env.test?

  # In test mode, call the delegator right away
  class DiscourseObserver < ActiveRecord::Observer
    alias_method :after_create, :after_create_delegator
    alias_method :after_destroy, :after_destroy_delegator
  end

else

  # Outside of test mode, use after_commit
  class DiscourseObserver < ActiveRecord::Observer
    def after_commit(model)
      if rails4?
        if model.send(:transaction_include_any_action?, [:create])
          after_create_delegator(model)
        end

        if model.send(:transaction_include_any_action?, [:destroy])
          after_destroy_delegator(model)
        end
      else
        if model.send(:transaction_include_action?, :create)
          after_create_delegator(model)
        end

        if model.send(:transaction_include_action?, :destroy)
          after_destroy_delegator(model)
        end
      end

    end
  end

end

