# frozen_string_literal: true

describe PostLocalizationUpdater do
  fab!(:user)
  fab!(:post) { Fabricate(:post, version: 99) }
  fab!(:group)
  fab!(:post_localization) do
    Fabricate(:post_localization, post: post, locale: "ja", raw: "古いバージョン")
  end

  fab!(:locale) { "ja" }
  let(:new_raw) { "新しいバージョンです" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "updates an existing localization" do
    localization =
      described_class.update(post_id: post.id, locale: locale, raw: new_raw, user: user)

    expect(localization).to have_attributes(
      raw: new_raw,
      cooked: PrettyText.cook(new_raw),
      localizer_user_id: user.id,
      post_version: post.version,
    )
  end

  it "returns the localization unchanged if the raw content is the same" do
    localization =
      described_class.update(post_id: post.id, locale:, raw: post_localization.raw, user:)

    expect(localization.id).to eq(post_localization.id)
    expect(localization.localizer_user_id).not_to eq(user.id)
  end

  it "enqueues ProcessLocalizedCook job" do
    loc = described_class.update(post_id: post.id, locale: locale, raw: new_raw, user: user)

    expect_job_enqueued(job: :process_localized_cooked, args: { post_localization_id: loc.id })
  end

  it "raises not found if the localization is missing" do
    expect {
      described_class.update(post_id: post.id, locale: "nope", raw: new_raw, user: user)
    }.to raise_error(Discourse::NotFound)
  end

  it "raises not found if the post is missing" do
    expect {
      described_class.update(post_id: -1, locale: locale, raw: new_raw, user: user)
    }.to raise_error(Discourse::NotFound)
  end

  context "with author localization" do
    fab!(:author, :user)
    fab!(:author_post) { Fabricate(:post, user: author) }
    fab!(:other_post, :post)
    fab!(:post_localization) { Fabricate(:post_localization, post: author_post, locale:) }

    before { SiteSetting.content_localization_allow_author_localization = true }

    it "allows post author to create localization for their own post" do
      localization =
        described_class.update(post_id: author_post.id, locale:, raw: new_raw, user: author)

      expect(localization).to have_attributes(
        post_id: author_post.id,
        locale:,
        raw: new_raw,
        localizer_user_id: author.id,
      )
    end

    it "raises permission error if user is not the post author" do
      expect {
        described_class.update(post_id: other_post.id, locale:, raw: new_raw, user: author)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
