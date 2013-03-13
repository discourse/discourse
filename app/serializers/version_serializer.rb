class VersionSerializer < ApplicationSerializer

  attributes :number, :display_username, :created_at

  def number
    object[:number]
  end

  def display_username
    object[:display_username]
  end

  def created_at
    object[:created_at]
  end

end
