require "metamorpher"

class RefactorWhereFirstToFindBy
  include Metamorpher::Refactorer
  include Metamorpher::Builders::Ruby

  def pattern
    builder.build("TYPE.where(PARAMS_).first")
  end

  def replacement
    builder.build("TYPE.find_by(PARAMS_)")
  end
end
