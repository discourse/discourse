# The SpamRulesEnforcer class takes action against users based on flags that their posts
# receive, their trust level, etc.
class SpamRulesEnforcer

  # The exclamation point means that this method may make big changes to posts and users.
  def self.enforce!(arg)
    SpamRulesEnforcer.new(arg).enforce!
  end

  def initialize(arg)
    @user = arg if arg.is_a?(User)
    @post = arg if arg.is_a?(Post)
  end

  def enforce!
    if @user
      SpamRule::AutoBlock.new(@user).perform
    end
    if @post
      SpamRule::FlagSockpuppets.new(@post).perform
    end
    true
  end

end
