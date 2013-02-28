class TrustLevel

  attr_reader :id, :name

  class << self
    def levels
      { new: 0,
        basic: 1,
        regular: 2,
        experienced: 3,
        advanced: 4,
        moderator: 5 }
    end
    alias_method :Levels, :levels

    def all
      levels.map do |name_key, id|
        TrustLevel.new(name_key, id)
      end
    end

    def valid_level?(level)
      levels.has_key?(level)
    end

    def compare(current_level, level)
      (current_level || levels[:new]) >= levels[level]
    end

    def level_key(level)
      levels.invert[level]
    end
  end

  def initialize(name_key, id)
    @name = I18n.t("trust_levels.#{name_key}.title")
    @id = id
  end

  def serializable_hash
    { id: @id, name: @name }
  end
end
