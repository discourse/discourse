# frozen_string_literal: true

RSpec.describe Migrations::Importer::PostNumbering do
  subject(:numbering) { described_class.new(intermediate_db, discourse_db) }

  include_context "with importer databases"

  let(:discourse_db) { instance_double(Migrations::Importer::DiscourseDB) }

  def create_post(original_id, topic_id:, post_number: nil, created_at: nil)
    Migrations::Database::IntermediateDB::Post.create(
      original_id:,
      topic_id:,
      post_number:,
      created_at: created_at && Time.utc(2024, 1, 1) + created_at,
      raw: "post #{original_id}",
    )
  end

  it "assigns contiguous numbers in source post number order" do
    create_post(1, topic_id: 10, post_number: 7)
    create_post(2, topic_id: 10, post_number: 1)
    create_post(3, topic_id: 10, post_number: 4)

    numbering.assign

    expect(post_numbers).to eq({ 1 => 3, 2 => 1, 3 => 2 })
  end

  it "sorts posts without a source number last" do
    create_post(1, topic_id: 10)
    create_post(2, topic_id: 10, post_number: 4)

    numbering.assign

    expect(post_numbers).to eq({ 1 => 2, 2 => 1 })
  end

  it "uses the source ID to order duplicate source numbers" do
    create_post(2, topic_id: 10, post_number: 2)
    create_post(1, topic_id: 10, post_number: 2)

    numbering.assign

    expect(post_numbers).to eq({ 1 => 1, 2 => 2 })
  end

  it "numbers each topic on its own" do
    create_post(1, topic_id: 10, post_number: 9)
    create_post(2, topic_id: 10)
    create_post(3, topic_id: 20)

    numbering.assign

    expect(post_numbers).to eq({ 1 => 1, 2 => 2, 3 => 1 })
  end

  it "numbers posts after posts already in a mapped destination topic" do
    add_mapping(10, mapping_type::TOPICS, 100)
    create_post(1, topic_id: 10, post_number: 1, created_at: 100)
    create_post(2, topic_id: 10, post_number: 7, created_at: 200)
    allow(discourse_db).to receive(:query_array).and_return([[100, 5]])

    numbering.assign

    expect(post_numbers).to eq({ 1 => 6, 2 => 7 })
  end

  it "stores the topic a number belongs to" do
    create_post(1, topic_id: 10, post_number: 3)

    numbering.assign

    rows = intermediate_db.query("SELECT * FROM mapped.post_numbers")
    expect(rows).to eq([{ original_id: 1, topic_original_id: 10, post_number: 1 }])
  end

  it "keeps the numbers of an earlier run" do
    create_post(1, topic_id: 10, created_at: 100)
    numbering.assign

    create_post(2, topic_id: 10, created_at: 200)
    numbering.assign

    expect(post_numbers).to eq({ 1 => 1, 2 => 2 })
  end
end
