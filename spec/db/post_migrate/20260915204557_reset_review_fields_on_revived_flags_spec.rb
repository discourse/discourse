# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20260915204557_reset_review_fields_on_revived_flags.rb")

RSpec.describe ResetReviewFieldsOnRevivedFlags do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  fab!(:moderator)
  fab!(:flagger, :user)

  def flag(post, type: :inappropriate, user: flagger, **attrs)
    Fabricate(:post_action, post:, user:, post_action_type_id: PostActionType.types[type], **attrs)
  end

  it "clears the review of revived flags backing a pending reviewable" do
    post = Fabricate(:reviewable_flagged_post).target
    agreed = flag(post, created_at: 1.hour.ago, agreed_at: 2.days.ago, agreed_by_id: moderator.id)
    deferred =
      flag(
        post,
        type: :spam,
        user: Fabricate(:user),
        created_at: 1.hour.ago,
        deferred_at: 2.days.ago,
        deferred_by_id: moderator.id,
      )

    described_class.new.up

    expect([agreed.reload, deferred.reload]).to all(
      have_attributes(agreed_at: nil, agreed_by_id: nil, deferred_at: nil, deferred_by_id: nil),
    )
  end

  it "keeps reviews made after the flag was created, and revived flags on resolved reviewables" do
    pending_post = Fabricate(:reviewable_flagged_post).target
    reviewed_after_creation =
      flag(pending_post, created_at: 2.days.ago, agreed_at: 1.day.ago, agreed_by_id: moderator.id)

    resolved_post = Fabricate(:reviewable_flagged_post, status: :approved).target
    revived_on_resolved =
      flag(resolved_post, created_at: 1.hour.ago, agreed_at: 2.days.ago, agreed_by_id: moderator.id)

    described_class.new.up

    expect([reviewed_after_creation.reload, revived_on_resolved.reload]).to all(
      have_attributes(agreed_by_id: moderator.id),
    )
  end

  it "skips a revived flag that would collide with the user's other open flag on the post" do
    post = Fabricate(:reviewable_flagged_post).target
    revived =
      flag(post, created_at: 1.hour.ago, deferred_at: 2.days.ago, deferred_by_id: moderator.id)
    # Validations prevent this pair today, but older data can still hold it.
    Fabricate.build(
      :post_action,
      post:,
      user: flagger,
      post_action_type_id: PostActionType.types[:spam],
    ).save!(validate: false)

    expect { described_class.new.up }.not_to raise_error

    expect(revived.reload.deferred_by_id).to eq(moderator.id)
  end
end
