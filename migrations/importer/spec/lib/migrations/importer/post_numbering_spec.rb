# frozen_string_literal: true

RSpec.describe Migrations::Importer::PostNumbering do
  subject(:numbering) { described_class.new(intermediate_db) }

  include_context "with importer databases"

  def create_post(original_id, topic_id:, post_number: nil, created_at: nil)
    Migrations::Database::IntermediateDB::Post.create(
      original_id:,
      topic_id:,
      post_number:,
      created_at: created_at && Time.utc(2024, 1, 1) + created_at,
      raw: "post #{original_id}",
    )
  end

  it "keeps a source number that is unique within its topic" do
    create_post(1, topic_id: 10, post_number: 1)
    create_post(2, topic_id: 10, post_number: 7)

    numbering.assign

    expect(post_numbers).to eq({ 1 => 1, 2 => 7 })
  end

  it "numbers posts without a source number after the topic's highest kept number" do
    create_post(1, topic_id: 10, post_number: 4)
    create_post(2, topic_id: 10, created_at: 200)
    create_post(3, topic_id: 10, created_at: 100)

    numbering.assign

    expect(post_numbers).to eq({ 1 => 4, 2 => 6, 3 => 5 })
  end

  it "reassigns every post of a duplicated source number" do
    create_post(1, topic_id: 10, post_number: 2, created_at: 100)
    create_post(2, topic_id: 10, post_number: 2, created_at: 200)
    create_post(3, topic_id: 10, post_number: 5, created_at: 300)

    numbering.assign

    expect(post_numbers).to eq({ 3 => 5, 1 => 6, 2 => 7 })
  end

  it "ignores a source number that is zero or negative" do
    create_post(1, topic_id: 10, post_number: 0, created_at: 100)
    create_post(2, topic_id: 10, post_number: -3, created_at: 200)

    numbering.assign

    expect(post_numbers).to eq({ 1 => 1, 2 => 2 })
  end

  it "numbers each topic on its own" do
    create_post(1, topic_id: 10, post_number: 9)
    create_post(2, topic_id: 10, created_at: 100)
    create_post(3, topic_id: 20, created_at: 100)

    numbering.assign

    expect(post_numbers).to eq({ 1 => 9, 2 => 10, 3 => 1 })
  end

  it "stores the topic a number belongs to" do
    create_post(1, topic_id: 10, post_number: 3)

    numbering.assign

    rows = intermediate_db.query("SELECT * FROM mapped.post_numbers")
    expect(rows).to eq([{ original_id: 1, topic_original_id: 10, post_number: 3 }])
  end

  it "keeps the numbers of an earlier run" do
    create_post(1, topic_id: 10, created_at: 100)
    numbering.assign

    create_post(2, topic_id: 10, created_at: 200)
    numbering.assign

    expect(post_numbers).to eq({ 1 => 1, 2 => 2 })
  end
end
