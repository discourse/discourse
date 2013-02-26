class TrustLevel

  attr_reader :id, :name

  def self.Levels
    {:new => 0,
     :basic => 1,
     :regular => 2,
     :experienced => 3,
     :advanced => 4,
     :moderator => 5}
  end

  def self.all
    self.Levels.map do |name_key, id|
      TrustLevel.new(name_key, id)
    end
  end

  def initialize(name_key, id)
    @name = I18n.t("trust_levels.#{name_key}.title")
    @id = id
  end

  def serializable_hash
    {id: @id, name: @name}
  end
end
