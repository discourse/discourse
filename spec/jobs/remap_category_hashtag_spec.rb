# frozen_string_literal: true

RSpec.describe Jobs::RemapCategoryHashtag do
  it "remaps inline so in-flight jobs still work after a deploy" do
    category = Fabricate(:category, slug: "support")
    post = create_post(raw: "See #support for details.")

    category.update!(slug: "help")
    described_class.new.execute(category_id: category.id, old_ref: "support", new_ref: "help")

    expect(post.reload.raw).to eq("See #help for details.")
  end

  it "does nothing when the category is gone" do
    post = create_post(raw: "See #support for details.")

    described_class.new.execute(category_id: -1, old_ref: "support", new_ref: "help")

    expect(post.reload.raw).to eq("See #support for details.")
  end
end
