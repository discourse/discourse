# frozen_string_literal: true

class DiscardedDraftSerializer < DraftSerializer
  attributes :id, :deleted_at
end
