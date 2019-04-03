class ReadThroughCache

  def self.fetch(scope, key, expires_in = 1.hour)
    Rails.cache.fetch("#{scope}/#{key}", expires_in: expires_in) do
      yield
    end
  end

  def self.invalidate(scope, key)
    Rails.cache.delete("#{scope}/#{key}")
  end

end
