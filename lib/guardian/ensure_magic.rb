# frozen_string_literal: true

# Support for ensure_{blah}! methods.
module EnsureMagic
  def method_missing(method, *args, &block)
    if method.to_s =~ /\Aensure_(.*)\!\z/
      can_method = :"#{Regexp.last_match[1]}?"

      if respond_to?(can_method)
        unless send(can_method, *args, &block)
          raise Discourse::InvalidAccess.new("#{can_method} failed")
        end
        return
      end
    end

    super.method_missing(method, *args, &block)
  end

  # Make sure we can see the object. Will raise a NotFound if it's nil
  def ensure_can_see!(obj)
    raise Discourse::InvalidAccess.new("Can't see #{obj}") if cannot_see?(obj)
  end
end
