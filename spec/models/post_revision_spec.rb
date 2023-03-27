# frozen_string_literal: true

RSpec.describe PostRevision do
  it "can deserialize old YAML" do
    # Date objects are stored in core post_revisions prior
    # to https://github.com/discourse/discourse/commit/e7f251c105
    # and are also stored by some plugins

    pr = Fabricate(:post_revision)
    DB.exec("UPDATE post_revisions SET modifications = ?", <<~YAML)
      ---
      last_version_at:
      - 2013-12-12 21:40:13.225239000 Z
      - 2013-12-12 22:10:51.433689320 Z
    YAML
    pr.reload
    expect(pr.modifications).to eq(
      {
        "last_version_at" => [
          Time.parse("2013-12-12 21:40:13.225239000 Z"),
          Time.parse("2013-12-12 22:10:51.433689320 Z"),
        ],
      },
    )
  end

  it "can serialize and deserialize symbols" do
    # Plugins may store symbolized values in this column
    pr = Fabricate(:post_revision, modifications: { key: :value })
    pr.reload
    expect(pr.modifications).to eq({ key: :value })
  end
end
