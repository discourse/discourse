# frozen_string_literal: true

RSpec.describe Jobs::RemapHashtag do
  def run(remaps)
    described_class.new.execute(remaps:)
  end

  def tag_remap(tag, old_ref)
    { "type" => "tag", "id" => tag.id, "old_ref" => old_ref }
  end

  it "remaps a renamed tag" do
    tag = Fabricate(:tag, name: "support")
    post = create_post(raw: "See #support for details.")

    tag.update!(name: "help")
    run([tag_remap(tag, "support")])

    expect(post.reload.raw).to eq("See #help for details.")
  end

  it "remaps a renamed category, including its subcategories" do
    parent = Fabricate(:category, slug: "support")
    child = Fabricate(:category, slug: "bucks", parent_category: parent)
    post = create_post(raw: "See #support and #support:bucks.")

    parent.update!(slug: "help")
    run(
      [
        { "type" => "category", "id" => parent.id, "old_ref" => "support" },
        { "type" => "category", "id" => child.id, "old_ref" => "support:bucks" },
      ],
    )

    expect(post.reload.raw).to eq("See #help and #help:bucks.")
  end

  it "uses the record's current reference, not the one it was enqueued with" do
    tag = Fabricate(:tag, name: "support")
    post = create_post(raw: "See #support for details.")

    tag.update!(name: "help")
    tag.update!(name: "assistance")
    run([tag_remap(tag, "support")])

    expect(post.reload.raw).to eq("See #assistance for details.")
  end

  it "does nothing when the record no longer exists" do
    tag = Fabricate(:tag, name: "support")
    post = create_post(raw: "See #support for details.")
    remap = tag_remap(tag, "support")

    tag.destroy!
    run([remap])

    expect(post.reload.raw).to eq("See #support for details.")
  end

  it "does nothing when only the casing changed" do
    SiteSetting.force_lowercase_tags = false
    tag = Fabricate(:tag, name: "Support")
    post = create_post(raw: "See #Support for details.")

    tag.update!(name: "support")
    run([tag_remap(tag, "Support")])

    expect(post.reload.raw).to eq("See #Support for details.")
  end

  it "refuses to write a reference the matcher cannot read back" do
    tag = Fabricate(:tag, name: "support")
    post = create_post(raw: "See #support for details.")

    tag.update_columns(name: "not a ref")
    run([tag_remap(tag, "support")])

    expect(post.reload.raw).to eq("See #support for details.")
  end

  it "ignores malformed entries" do
    expect { run([{ "type" => "tag" }, { "id" => 1 }, {}]) }.not_to raise_error
  end
end
