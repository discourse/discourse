class VersionSerializer < ApplicationSerializer

  attributes :number, :display_username, :created_at, :description

  def number
    object[:number]
  end

  def display_username
    object[:display_username]
  end

  def created_at
    object[:created_at]
  end

  def description
    "v#{object[:number]} - #{FreedomPatches::Rails4.time_ago_in_words(object[:created_at])} ago by #{object[:display_username]}"
  end

end
