module ActionDispatch
  class Request
    def [](key)
      params[key.to_s]
    end

    def []=(key, value)
      params[key.to_s] = value
    end
  end
end
