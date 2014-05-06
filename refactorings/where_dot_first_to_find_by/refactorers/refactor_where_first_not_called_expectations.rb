require "metamorpher"

class RefactorWhereFirstNotCalledExpectations
  include Metamorpher::Refactorer
  include Metamorpher::Builders::Ruby

  def pattern
    builder.build("TYPE.expects(:where).never")
  end

  def replacement
    builder.build("TYPE.expects(:find_by).never")
  end
end
