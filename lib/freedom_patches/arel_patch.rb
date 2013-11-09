if rails4?
  # https://github.com/rails/arel/pull/206
  class Arel::Table
    def hash
      @name.hash
    end
  end
end
