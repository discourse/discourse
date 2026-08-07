# frozen_string_literal: true

RSpec.describe Jobs::RemapCategoryHashtag do
  it "rewrites category hashtag refs and rebakes posts" do
    parent_category = Fabricate(:category, slug: "support")
    category = Fabricate(:category, slug: "bucks", parent_category: parent_category)
    post = create_post(raw: "See #support:bucks for details.")

    parent_category.update!(slug: "help")

    described_class.new.execute(
      category_id: category.id,
      old_ref: "support:bucks",
      new_ref: "help:bucks",
    )

    post.reload
    category.reload

    expect(post.raw).to eq("See #help:bucks for details.")
    expect(post.cooked).to include(category.url)
  end

  it "rewrites only standalone matching hashtag refs" do
    category = Fabricate(:category, slug: "bug")
    post = create_post(raw: "#bug #bug-more #bug:suffix #bug::tag #other:bug #bug.")

    category.update!(slug: "issue")

    described_class.new.execute(category_id: category.id, old_ref: "bug", new_ref: "issue")

    expect(post.reload.raw).to eq("#issue #bug-more #bug:suffix #bug::tag #other:bug #issue.")
  end

  it "skips raw matches that were cooked for a different category" do
    category = Fabricate(:category, slug: "bug")
    other_category = Fabricate(:category, slug: "other")
    post = create_post(raw: "See #bug")

    category.update!(slug: "issue")

    described_class.new.execute(category_id: other_category.id, old_ref: "bug", new_ref: "issue")

    expect(post.reload.raw).to eq("See #bug")
  end

  it "skips raw matches when the category no longer exists" do
    category = Fabricate(:category, slug: "bug")
    post = create_post(raw: "See #bug")
    category_id = category.id

    category.destroy!

    described_class.new.execute(category_id:, old_ref: "bug", new_ref: "issue")

    expect(post.reload.raw).to eq("See #bug")
  end

  it "uses the current category ref as the replacement target" do
    category = Fabricate(:category, slug: "bug")
    post = create_post(raw: "See #bug")

    category.update!(slug: "issue")
    category.update!(slug: "defect")

    described_class.new.execute(category_id: category.id, old_ref: "bug", new_ref: "issue")

    expect(post.reload.raw).to eq("See #defect")
  end
end
