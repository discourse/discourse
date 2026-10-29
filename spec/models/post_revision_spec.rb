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

  it "can't be hidden and unlisted at the same time" do
    post_revision = Fabricate(:post_revision, hidden: true)

    expect { post_revision.unlist! }.to raise_error(ActiveRecord::CheckViolation)
  end

  it "relists an unlisted revision when hiding it" do
    post_revision = Fabricate(:post_revision, unlisted: true)

    post_revision.hide!

    expect(post_revision.reload).to have_attributes(hidden: true, unlisted: false)
  end

  describe ".latest_for" do
    fab!(:post)
    fab!(:listed_revision) { Fabricate(:post_revision, post:, number: 2) }
    fab!(:unlisted_revision) { Fabricate(:post_revision, post:, number: 3, unlisted: true) }

    it "returns the latest listed revision when skipping unlisted ones" do
      expect(described_class.latest_for(post, Guardian.new)).to eq(listed_revision)
    end

    it "returns the latest unlisted revision when no listed one is left" do
      listed_revision.unlist!

      expect(described_class.latest_for(post, Guardian.new)).to eq(unlisted_revision)
    end
  end
end
