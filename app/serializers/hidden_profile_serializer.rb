class HiddenProfileSerializer < BasicUserSerializer
  attributes :profile_hidden?

  def profile_hidden?
    true
  end
end
