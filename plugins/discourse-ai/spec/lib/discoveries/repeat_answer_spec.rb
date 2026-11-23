# frozen_string_literal: true

RSpec.describe DiscourseAi::Discoveries::RepeatAnswer do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:post)
  fab!(:agent, :ai_agent)
  fab!(:llm, :llm_model)

  let(:source) { { "post_id" => post.id, "post_updated_at" => post.updated_at.iso8601(6) } }

  before { enable_current_plugin }

  def cache_for(query, reader: user)
    described_class.new(
      user: reader,
      query:,
      requested_scope: nil,
      scope: nil,
      agent:,
      llm:,
      settings: {
      },
    )
  end

  def store(cache)
    cache.write(candidates: [source], sources: [source], answer: "A completed answer")
  end

  it "evicts the oldest of ten distinct answers only for the user who wrote the new answer" do
    caches = Array.new(10) { |number| cache_for("Question #{number}") }
    other_cache = cache_for("Question 0", reader: other_user)
    expect((caches + [other_cache]).map { |cache| store(cache) }).to all(eq(0))

    expect(caches.first.read).to include(answer: "A completed answer")
    newest = cache_for("Question 10")
    expect(store(newest)).to eq(1)

    expect(caches.first.read).to be_nil
    expect((caches.drop(1) + [newest, other_cache]).map(&:read)).to all(
      include(answer: "A completed answer"),
    )
  end

  it "updates a regenerated answer's position without using another slot" do
    caches = Array.new(10) { |number| cache_for("Question #{number}") }
    caches.each { |cache| store(cache) }

    expect(store(caches.first)).to eq(0)
    expect(store(cache_for("Question 10"))).to eq(1)

    expect(caches.first.read).to include(answer: "A completed answer")
    expect(caches.second.read).to be_nil
  end
end
