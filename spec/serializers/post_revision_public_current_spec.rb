# frozen_string_literal: true

RSpec.describe PostRevisionSerializer do
  fab!(:reader, :user)
  fab!(:post) { Fabricate(:post, raw: "Bob here") }

  before do
    SiteSetting.editing_grace_period = 0
    SiteSetting.edit_history_visible_to_public = true
    post.revise(post.user, raw: "Bob is here")
    post.revise(post.user, raw: "Confidential historical body", edit_reason: "Confidential reason")
    post.revise(post.user, raw: "Another historical body")
    post.revise(post.user, raw: "Bob was here")
    post.revisions.find_by!(number: 3).hide!
  end

  def serialize_revision(number = nil, user: reader, **options)
    guardian = user ? user.guardian : Guardian.new
    revision =
      number ? post.revisions.find_by!(number: number) : PostRevision.latest_for(post, guardian)
    revision.post = post
    described_class.new(revision, scope: guardian, root: false, **options).as_json
  end

  it "compares the last accessible body with the current post across a hidden third version" do
    [reader, nil].each do |user|
      json = serialize_revision(user: user)
      comparison = json.fetch(:public_current_comparison)

      expect(comparison).to include(from_version: 2, to_version: 5)
      expect(comparison.keys).to contain_exactly(:from_version, :to_version, :body_changes)
      expect(comparison[:body_changes].keys).to contain_exactly(
        :inline,
        :side_by_side,
        :side_by_side_markdown,
      )
      expect(comparison[:body_changes][:side_by_side]).to include("Bob", "is", "was", "here")
      expect(json).to include(previous_hidden: true, body_changes: nil)
      expect(json).not_to have_key(:title_changes)
      [3, 4].each do |number|
        revision = post.revisions.find_by!(number: number)
        expect(json.to_json).not_to include(revision.modifications["raw"].last)
      end
      expect(json.to_json).not_to include(
        post.revisions.find_by!(number: 3).modifications["edit_reason"].last,
      )
    end
  end

  it "also compares with the live body when all subsequent revisions are hidden" do
    post.revisions.where(number: 4..5).each(&:hide!)

    expect(serialize_revision.fetch(:public_current_comparison)).to include(
      from_version: 2,
      to_version: 5,
    )
  end

  it "keeps the comparison off older history pages and staff history" do
    expect(serialize_revision(2)).not_to have_key(:public_current_comparison)
    expect(serialize_revision(user: Fabricate(:admin))).not_to have_key(:public_current_comparison)
  end

  it "leaves ordinary and unlisted history unchanged" do
    post.revisions.update_all(hidden: false)
    post.revisions.find_by!(number: 3).unlist!

    expect(serialize_revision).not_to have_key(:public_current_comparison)
    expect(serialize_revision[:body_changes]).to be_present
  end

  it "does not use an unauthorized baseline outside the loaded history window" do
    stub_const(PostRevision, :HISTORY_WINDOW, 2) do
      expect(serialize_revision).not_to have_key(:public_current_comparison)
    end
  end

  it "does not compare bodies when the post or its history is inaccessible" do
    SiteSetting.edit_history_visible_to_public = false
    expect(serialize_revision).not_to have_key(:public_current_comparison)
    SiteSetting.edit_history_visible_to_public = true
    post.update!(deleted_at: Time.zone.now)
    expect(serialize_revision).not_to have_key(:public_current_comparison)
    post.update!(deleted_at: nil)
    post.topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
    expect(serialize_revision).not_to have_key(:public_current_comparison)
  end

  it "keeps a hidden comparison available when the latest entry is unlisted" do
    post.revisions.find_by!(number: 5).unlist!

    expect(serialize_revision.fetch(:public_current_comparison)).to include(
      from_version: 2,
      to_version: 5,
    )
    expect(
      serialize_revision(5, include_unlisted: true).fetch(:public_current_comparison),
    ).to include(from_version: 2, to_version: 5)
  end

  it "handles comparisons that exceed the diff limit without exposing a partial body" do
    error =
      ONPDiff::DiffLimitExceeded.new(
        comparisons_used: 1,
        comparison_budget: 0,
        left_size: 1,
        right_size: 1,
      )
    DiscourseDiff.any_instance.stubs(:inline_html).raises(error)

    expect(serialize_revision.fetch(:public_current_comparison)).to eq(
      from_version: 2,
      to_version: 5,
      diff_error: true,
    )
  end
end
