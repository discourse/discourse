# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20260422135650_strip_upload_label_escapes.rb")

describe StripUploadLabelEscapes do
  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  def raw_for(id)
    DB.query_single("SELECT raw FROM posts WHERE id = ?", id)[0]
  end

  it "strips accumulated backslashes from upload markdown labels" do
    damaged = Fabricate(:post, raw: "![foo\\\\\\\\_bar|100x100](upload://abc.jpg)")
    multi = Fabricate(:post, raw: "![My\\\\_Awesome\\\\_Photo|100x100](upload://abc.jpg)")
    clean = Fabricate(:post, raw: "![foo_bar|100x100](upload://abc.jpg)")
    outside =
      Fabricate(
        :post,
        raw: "keep \\_these\\_ — fix ![name\\\\\\\\_x|100x100](upload://abc.jpg) here",
      )
    unrelated = Fabricate(:post, raw: "plain \\_escape\\_ in prose")

    described_class.new.up

    expect(raw_for(damaged.id)).to eq("![foo_bar|100x100](upload://abc.jpg)")
    expect(raw_for(multi.id)).to eq("![My_Awesome_Photo|100x100](upload://abc.jpg)")
    expect(raw_for(clean.id)).to eq("![foo_bar|100x100](upload://abc.jpg)")
    expect(raw_for(outside.id)).to eq(
      "keep \\_these\\_ — fix ![name_x|100x100](upload://abc.jpg) here",
    )
    expect(raw_for(unrelated.id)).to eq("plain \\_escape\\_ in prose")
  end
end
