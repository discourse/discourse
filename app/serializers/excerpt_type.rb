module ExcerptType

  def self.included(base)
    base.attributes :type
  end

  def type
    self.class.name.sub(/ExcerptSerializer/, '')
  end

end
