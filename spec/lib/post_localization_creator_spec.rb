# frozen_string_literal: true

describe PostLocalizationCreator do
  fab!(:user)
  fab!(:post)
  fab!(:group)

  let(:locale) { "ja" }
  let(:raw) { "これは翻訳です。" }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = group.id.to_s
    group.add(user)
  end

  it "creates a post localization record" do
    localization = described_class.create(post_id: post.id, locale:, raw:, user:)

    expect(PostLocalization.find(localization.id)).to have_attributes(
      post_id: post.id,
      locale:,
      raw:,
      localizer_user_id: user.id,
      cooked: PrettyText.cook(raw),
    )
  end

  it "enqueues ProcessLocalizedCook job" do
    loc = described_class.create(post_id: post.id, locale:, raw:, user:)

    expect_job_enqueued(job: :process_localized_cooked, args: { post_localization_id: loc.id })
  end

  it "raises not found if the post is missing" do
    expect { described_class.create(post_id: -1, locale:, raw:, user:) }.to raise_error(
      Discourse::NotFound,
    )
  end

  context "with author localization" do
    fab!(:author, :user)
    fab!(:author_post) { Fabricate(:post, user: author) }
    fab!(:other_post, :post)

    before { SiteSetting.content_localization_allow_author_localization = true }

    it "allows post author to create localization for their own post" do
      localization = described_class.create(post_id: author_post.id, locale:, raw:, user: author)

      expect(localization).to have_attributes(
        post_id: author_post.id,
        locale:,
        raw:,
        localizer_user_id: author.id,
      )
    end

    it "raises permission error if user is not the post author" do
      expect {
        described_class.create(post_id: other_post.id, locale:, raw:, user: author)
      }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
