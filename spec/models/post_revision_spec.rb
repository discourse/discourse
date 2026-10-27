# frozen_string_literal: true

RSpec.describe PostRevision do
  describe "#rewrite_form_data" do
    it "rewrites answers and rendered history for a soft-deleted post" do
      template =
        Fabricate(:form_template, template: [{ id: "note", type: "input" }].as_json.to_yaml)
      original =
        FormTemplate::Submission.from_template(template, answers: { "note" => "Ask @oldname" })
      changed = original.with_answers({ "note" => "Invite @oldname" })
      post = Fabricate(:post, raw: changed.render, form_data: changed.to_h)
      revision =
        Fabricate(
          :post_revision,
          post:,
          form_data_changes: [original.to_h, changed.to_h],
          modifications: {
            "raw" => [original.render, changed.render],
          },
        )
      post.trash!

      revision.reload.rewrite_form_data { |text| text.gsub("@oldname", "@newname") }
      revision.save!

      expected_raw =
        [original, changed].map { |submission| submission.render.gsub("@oldname", "@newname") }
      expect(revision.reload.form_data_changes.map { |data| data.dig("answers", "note") }).to eq(
        ["Ask @newname", "Invite @newname"],
      )
      expect(revision.modifications["raw"]).to eq(expected_raw)
      expect(revision.modifications["cooked"]).to eq(expected_raw.map { |text| post.cook(text) })
    end
  end

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
