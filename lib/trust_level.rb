require_dependency 'enum'

class TrustLevel
  attr_reader :id, :name

  class << self
    def levels
      @levels ||= Enum.new(
        :newuser, :basic, :regular, :leader, :elder, start: 0
      )
    end

    def all
      levels.map do |name_key, id|
        TrustLevel.new(name_key, id)
      end
    end

    def valid_level?(level)
      levels.valid?(level)
    end

    def compare(current_level, level)
      (current_level || levels[:newuser]) >= levels[level] rescue binding.pry
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
