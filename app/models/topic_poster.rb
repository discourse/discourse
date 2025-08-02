# frozen_string_literal: true

class TopicPoster < OpenStruct
  include ActiveModel::Serialization

  attr_accessor :user, :description, :extras, :id, :primary_group

  def attributes
    {
      "user" => user,
      "description" => description,
      "extras" => extras,
      "id" => id,
      "primary_group" => primary_group,
    }
  end

  def name_and_description
    I18n.t("js.user.avatar.name_and_description", name: user.display_name, description: description)
  end
end
