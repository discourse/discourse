# frozen_string_literal: true

RSpec.describe Blog::Instance do
  subject(:seed_default_blog) do
    load Rails.root.join("plugins/blog/db/fixtures/001_default_blog_instance.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative
  end

  it "creates the default blog on a site without one" do
    described_class.delete_all

    seed_default_blog

    expect(described_class.sole).to have_attributes(
      name: described_class::DEFAULT_NAME,
      slug: "blog",
      is_default: true,
    )
  end
end
