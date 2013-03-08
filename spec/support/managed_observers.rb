module ManagedObservers

  # Temporarily activates a list of observers
  def with_observer(*observers)
    ActiveRecord::Base.observers.enable(*observers)
    yield
    ActiveRecord::Base.observers.disable(:all)
  end

  # plural alias to the previous method
  alias_method :with_observers, :with_observer

end
