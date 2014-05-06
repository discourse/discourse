require "metamorpher"

class RefactorWhereFirstStrictMocks
  include Metamorpher::Refactorer
  include Metamorpher::Builders::Ruby

  def pattern
    builder.build("TYPE.expects(:where).with(PARAMS_).returns(ARRAY_VALUE)")
  end

  def replacement
    builder
     .build("TYPE.expects(:find_by).with(PARAMS_).returns(SINGLE_VALUE)")
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
