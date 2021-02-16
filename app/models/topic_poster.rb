# frozen_string_literal: true

class TopicPoster < OpenStruct
  include ActiveModel::Serialization

  attr_accessor :user, :description, :extras, :id, :primary_group

  def attributes
    {
      'user' => user,
      'description' => description,
      'extras' => extras,
      'id' => id,
      'primary_group' => primary_group
    }
  end

  def name_and_description
    if SiteSetting.prioritize_username_in_ux? || user.name.blank?
      name = user.username
    else
      name = user.name
    end

    I18n.t("js.user.avatar.name_and_description", name: name, description: description)
  end
end
