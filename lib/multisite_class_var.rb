# Support for a class variable that is multisite aware.

module MultisiteClassVar

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def multisite_class_var(name, &default)
      @multisite_class_vars ||= {}
      @multisite_class_vars[name] = {}

      define_singleton_method(name) do
        @multisite_class_vars[name][RailsMultisite::ConnectionManagement.current_db] ||= default.call
      end
    end
  end

end
