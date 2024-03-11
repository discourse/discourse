# frozen_string_literal: true

module Chat
  class GroupMention < Mention
    belongs_to :group, foreign_key: :target_id
  end
end
