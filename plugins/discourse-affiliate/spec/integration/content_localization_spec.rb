# frozen_string_literal: true

describe "Affiliate links on localized posts" do
  fab!(:admin)
  fab!(:localizer_group) { Fabricate(:group, users: [admin]) }

  let(:amazon_url) { "https://www.amazon.de/gp/product/B0C3WGSSWC" }
  let(:affiliate_tag) { "tag=discourse-21" }

  before do
    enable_current_plugin
    stub_request(:get, /amazon\.de/).to_return(status: 200, body: "")
    stub_request(:head, /amazon\.de/).to_return(status: 200, body: "")
    Jobs.run_immediately!
    SiteSetting.affiliate_amazon_de = "discourse-21"
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_allowed_groups = localizer_group.id.to_s
  end

  def create_post_with_link
    create_post(raw: "Great deal at #{amazon_url}", user: admin).reload
  end

  it "applies affiliate codes to a newly created localization" do
    post = create_post_with_link

    localization =
      PostLocalizationCreator.create(
        post: post,
        locale: "ja",
        raw: "お得な情報 #{amazon_url}",
        user: admin,
      )

    expect(post.reload.cooked).to include(affiliate_tag)
    expect(localization.reload.cooked).to include(affiliate_tag)
  end

  it "applies affiliate codes to an updated localization" do
    post = create_post_with_link
    PostLocalizationCreator.create(post: post, locale: "ja", raw: "お得な情報", user: admin)

    localization =
      PostLocalizationUpdater.update(
        post: post,
        locale: "ja",
        raw: "更新されたお得な情報 #{amazon_url}",
        user: admin,
      )

    expect(localization.reload.cooked).to include(affiliate_tag)
  end

  it "applies affiliate codes to an existing localization when it is recooked" do
    post = create_post_with_link
    localization =
      PostLocalizationCreator.create(
        post: post,
        locale: "ja",
        raw: "お得な情報 #{amazon_url}",
        user: admin,
      )
    localization.update_column(:cooked, PrettyText.cook(localization.raw))
    expect(localization.reload.cooked).not_to include(affiliate_tag)

    Jobs::ProcessLocalizedCooked.new.execute(post_localization_id: localization.id, recook: true)

    expect(localization.reload.cooked).to include(affiliate_tag)
  end
end
