# The SpamRulesEnforcer class takes action against users based on flags that their posts
# receive, their trust level, etc.
class SpamRulesEnforcer

  def self.enforce!(arg)
    SpamRulesEnforcer.new(arg).enforce!
  end

  def initialize(arg)
    @user = arg if arg.is_a?(User)
    @post = arg if arg.is_a?(Post)
  end

  def enforce!
    I18n.with_locale(SiteSetting.default_locale) do
      SpamRule::AutoSilence.new(@user).perform if @user
      SpamRule::FlagSockpuppets.new(@post).perform if @post
    end
    true
  end

end
