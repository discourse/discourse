# frozen_string_literal: true

require Rails.root.join(
          "db/post_migrate/20260427053607_rewrite_ai_artifact_to_web_artifact_markup.rb",
        )

RSpec.describe RewriteAiArtifactToWebArtifactMarkup do
  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  fab!(:topic)
  fab!(:user)

  def make_post(raw:, cooked:)
    post = Fabricate(:post, topic: topic, user: user, raw: raw, skip_validation: true)
    DB.exec(<<~SQL, id: post.id, cooked: cooked)
      UPDATE posts SET cooked = :cooked WHERE id = :id
    SQL
    post
  end

  it "rewrites legacy ai-artifact markup in raw and cooked" do
    post =
      make_post(
        raw: %(Hello\n\n<div class="ai-artifact" data-ai-artifact-id="42"></div>),
        cooked: %(<p>Hello</p><div class="ai-artifact" data-ai-artifact-id="42"></div>),
      )

    described_class.new.up

    post.reload
    expect(post.raw).to include('class="web-artifact"')
    expect(post.raw).to include('data-web-artifact-id="42"')
    expect(post.raw).not_to include("ai-artifact")
    expect(post.cooked).to include('class="web-artifact"')
    expect(post.cooked).to include('data-web-artifact-id="42"')
    expect(post.cooked).not_to include("ai-artifact")
  end

  it "rewrites all artifact data attributes" do
    post = make_post(raw: <<~HTML, cooked: <<~HTML)
          <div class="ai-artifact"
            data-ai-artifact-id="1"
            data-ai-artifact-version="3"
            data-ai-artifact-height="400"
            data-ai-artifact-autorun="true"
            data-ai-artifact-seamless="1"></div>
        HTML
          <div class="ai-artifact"
            data-ai-artifact-id="1"
            data-ai-artifact-version="3"></div>
        HTML

    described_class.new.up

    post.reload
    %w[id version height autorun seamless].each do |attr|
      expect(post.raw).to include("data-web-artifact-#{attr}")
      expect(post.raw).not_to include("data-ai-artifact-#{attr}")
    end
    expect(post.cooked).to include("data-web-artifact-id")
    expect(post.cooked).to include("data-web-artifact-version")
  end

  it "clears baked_version so the post will rebake" do
    post =
      make_post(
        raw: %(<div class="ai-artifact" data-ai-artifact-id="1"></div>),
        cooked: %(<div class="ai-artifact" data-ai-artifact-id="1"></div>),
      )
    DB.exec("UPDATE posts SET baked_version = 5 WHERE id = #{post.id}")

    described_class.new.up

    post.reload
    expect(post.baked_version).to be_nil
  end

  it "does not touch posts without artifact markup" do
    post = make_post(raw: "Just a normal post.", cooked: "<p>Just a normal post.</p>")
    original_raw = post.raw
    original_cooked = post.cooked

    described_class.new.up

    post.reload
    expect(post.raw).to eq(original_raw)
    expect(post.cooked).to eq(original_cooked)
  end

  it "does not rewrite plain-text occurrences of 'ai-artifact'" do
    post =
      make_post(
        raw: "Did you know about the ai-artifact feature?",
        cooked: "<p>Did you know about the ai-artifact feature?</p>",
      )

    described_class.new.up

    post.reload
    expect(post.raw).to include("ai-artifact")
    expect(post.cooked).to include("ai-artifact")
  end

  it "supports single-quoted class attributes" do
    post =
      make_post(
        raw: "<div class='ai-artifact' data-ai-artifact-id='7'></div>",
        cooked: "<div class='ai-artifact' data-ai-artifact-id='7'></div>",
      )

    described_class.new.up

    post.reload
    expect(post.raw).to include("class='web-artifact'")
    expect(post.cooked).to include("class='web-artifact'")
  end

  it "rewrites posts beyond the first batch" do
    posts =
      3.times.map do |i|
        make_post(
          raw: %(<div class="ai-artifact" data-ai-artifact-id="#{i}"></div>),
          cooked: %(<div class="ai-artifact" data-ai-artifact-id="#{i}"></div>),
        )
      end

    stub_const(described_class, :BATCH_SIZE, 2) { described_class.new.up }

    posts.each do |post|
      post.reload
      expect(post.raw).to include("web-artifact")
      expect(post.raw).not_to include("ai-artifact")
    end
  end
end
