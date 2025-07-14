# frozen_string_literal: true

class PostVotingCommentValidator < ActiveModel::Validator
  def validate(record)
    raw_validator(record)
  end

  private

  def raw_validator(record)
    StrippedLengthValidator.validate(
      record,
      :raw,
      record.raw,
      SiteSetting.min_post_length..SiteSetting.post_voting_comment_max_raw_length,
    )

    sentinel = TextSentinel.body_sentinel(record.raw)
    record.errors.add(:raw, I18n.t(:is_invalid)) unless sentinel.valid?

    WatchedWordsValidator.new(attributes: [:raw]).validate(record)
  end
end
