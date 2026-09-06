# frozen_string_literal: true

class CustomEmoji::ImportRowSerializer < ApplicationSerializer
  attributes :index,
             :name,
             :group,
             :filename,
             :category,
             :errors,
             :incoming_url,
             :existing_url,
             :existing_group

  def group
    object.display_group
  end

  def existing_group
    object.display_existing_group
  end

  def include_errors?
    object.invalid?
  end

  def include_incoming_url?
    object.incoming_url.present?
  end

  def include_existing_url?
    object.conflict? && object.existing_url.present?
  end

  def include_existing_group?
    object.conflict?
  end
end
