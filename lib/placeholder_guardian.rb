# frozen_string_literal: true

# Class that provides a "placeholder Guardian" until real Guardian is available
#
# As part of the transition to ensuring that every Serializer has an appropriate
# Guardian available as its scope, ApplicationSerializer#initialize checks that
# it has been called with a scope: argument.  However, it may not be immediately
# clear what the correct value for that scope: argument should be.
#
# In such cases, a developer can use the syntax "scope: PlaceholderGuardian.new"
# to both:
#  * satisfy the requirement that "scope:" is specified; and,
#  * indicate that a correct value still needs to be figured out.
#
# By default, "PlaceholderGuardian.new" evaluates to nil.  This is because the
# legacy code in many Serializers was perfectly happy to have no "scope:" argument
# at all, because no code happened to use the scope.
#
# When a developer adds new code that does try to use a serializer's scope value
# (i.e., calls a method on the scope), and that code fails because the scope is nil,
# they will want to know where that nil value came from.  Setting the "@@exploding"
# variable to true will cause any attempt to call a method on a PlaceholderGuardian
# object to reveal where that object was instantiated.  Then, the developer can pin
# down which PlaceholderGuardian needs to (finally) be replaced with a real Guardian.
#
class PlaceholderGuardian < Guardian

  # When true, PlaceholderGuardian.new produces an "exploding placeholder" that
  # reveals its point-of-construction when something tries to access it.
  @@exploding = (ApplicationSerializer.require_strict_scope === :only_guardian)

  class << self
    def new(...)
      if @@exploding
        super
      else
        nil
      end
    end
  end

  # Undefine all the methods that were defined by Guardian.
  instance_methods.difference(Object.instance_methods).each { |name| undef_method(name) }

  def initialize(...)
    # Record the site where initialize() was called.
    @origin_caller = caller(2, 3)
  end

  def method_missing(*args)
    # If anything tries to call one of the original Guardian methods, explode
    # with a message that reveals where this instance was constructed.
    raise(
      "Something tried to actually use a PlaceholderGuardian that was constructed here: \n#{@origin_caller.join("\n")}",
    )
  end
end
