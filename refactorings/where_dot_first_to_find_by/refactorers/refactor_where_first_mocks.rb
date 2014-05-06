require "metamorpher"

class RefactorWhereFirstMocks
  include Metamorpher::Refactorer
  include Metamorpher::Builders::Ruby

  def pattern
    builder
     .build("TYPE.DOUBLE_METHOD(:where).returns(ARRAY_VALUE)")
     .ensuring("DOUBLE_METHOD") { |m| m.name == :expects || m.name == :stubs }
     .ensuring("ARRAY_VALUE") { |v| v.name == :array }
     # Doesn't match non-array return types, such as Topic.stubs(:where).returns(Topic)
  end

  def replacement
    builder
     .build("TYPE.DOUBLE_METHOD(:find_by).returns(SINGLE_VALUE)")
     .deriving("SINGLE_VALUE", "ARRAY_VALUE") { |array_value| take_first(array_value) }
  end

  private

  # Refactor the argument from [] to nil, or from [X] to X
  def take_first(array_value)
    if array_value.children.empty?
      builder.build("nil")
    else
      array_value.children.first
    end
  end
end
