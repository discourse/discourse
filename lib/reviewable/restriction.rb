# frozen_string_literal: true

class Reviewable::Restriction
  attr_reader :kind, :created_at, :locale, :raw, :cooked, :account_id, :expires_at, :content_kind

  def initialize(kind:, target:, expires_at: nil, content_kind: nil)
    @kind = kind
    @expires_at = expires_at
    @created_at = target.created_at
    @locale = target.try(:locale) unless target.is_a?(User)
    @content_kind = content_kind || (target.is_a?(User) ? :account : :content)
    @account_id = target.is_a?(User) ? target.id : target.try(:user_id)
    @raw = target.try(:raw)&.dup
    @cooked = target.try(:cooked)&.dup
    if target.is_a?(ReviewableQueuedPost)
      @raw = target.payload["raw"]&.dup
      @locale = target.payload["locale"]
      @account_id = target.target_created_by_id
    end
  end
end
