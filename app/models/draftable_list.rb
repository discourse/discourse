# frozen_string_literal: true

class DraftableList
  include ActiveModel::Serialization

  def initialize(user)
    @current_user = user
  end

  def draft_key
    @draft_key || Draft::NEW_TOPIC
  end

  def draft_sequence
    @draft_sequence || DraftSequence.current(@current_user, draft_key)
  end

  def draft
    @draft || Draft.get(@current_user, draft_key, draft_sequence) if @current_user
  end

  def draft_key=(key)
    @draft_key = key
  end

  def draft_sequence=(sequence)
    @draft_sequence = sequence
  end

  def draft=(draft)
    @draft = draft
  end
end
