# frozen_string_literal: true

module ::Blog
  # What an anonymous reviewer receives; nothing that identifies the draft or its editors.
  class ReviewSnapshotSerializer < ApplicationSerializer
    attributes :title, :cooked, :post_version, :created_at, :expires_at
  end
end
