# frozen_string_literal: true

require "onebox/json_ld"

RSpec.describe Onebox::JsonLd do
  it "logs warning and returns an empty hash if received json is invalid" do
    invalid_json = "{\"@type\":invalid-json}"
    doc = Nokogiri.HTML("<script type=\"application/ld+json\">#{invalid_json}</script>")
    Discourse.expects(:warn_exception).with(
      instance_of(JSON::ParserError),
      message: "Error parsing JSON-LD: #{invalid_json}",
    )

    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq({})
  end

  it "returns an empty hash if there is no JSON-LD script tag" do
    doc = Nokogiri.HTML("<script type=\"something else\"></script>")
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq({})
  end

  it "returns an empty hash if there is no JSON-LD data" do
    doc = Nokogiri.HTML("<script type=\"application/ld+json\"></script>")
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq({})
  end

  it "returns an empty hash if the type of JSON-LD data is not Movie" do
    doc =
      Nokogiri.HTML(
        "<script type=\"application/ld+json\">{\"@type\":\"Something Else\",\"aggregateRating\":{\"@type\":\"AggregateRating\",\"ratingCount\":806928,\"bestRating\":10,\"worstRating\":1}}</script>",
      )
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq({})
  end

  it "correctly normalizes the properties" do
    doc = Nokogiri.HTML(onebox_response("imdb"))
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq(expected_movie_hash)
  end

  it "does not fail when there is more than one JSON-LD element" do
    doc = Nokogiri.HTML(onebox_response("imdb"))
    doc.css("body")[
      0
    ] << "<script type=\"application/ld+json\">{\"@context\":\"http://schema.org\",\"@type\":\"WebPage\",\"url\":\"https:\/\/imdb.com\",\"description\":\"Movies\"}</script>"
    Discourse.expects(:warn_exception).never

    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq(expected_movie_hash)
  end

  it "returns first supported type when JSON-LD is an array" do
    array_json =
      '<script type="application/ld+json">[{"@type": "Something Else"}, {"@context":"https://schema.org","@type":"Movie","url":"/title/tt2358891/","name":"La grande bellezza","alternateName":"The Great Beauty"}]</script>'
    doc = Nokogiri.HTML(array_json)
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq(
      {
        description: nil,
        duration: nil,
        genres: nil,
        image: nil,
        name: "La grande bellezza",
        rating: nil,
      },
    )
  end

  it "does not fail when JSON-LD returns an array with no supported types" do
    array_json =
      '<script type="application/ld+json">[{"@type": "Something Else"}, {"@context":"https://schema.org","@type":"Nothing"},{"@context":"https://schema.org"}]</script>'
    doc = Nokogiri.HTML(array_json)
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq({})
  end

  private

  def expected_movie_hash
    {
      name: "Rudy",
      image:
        "https://m.media-amazon.com/images/M/MV5BZGUzMDU1YmQtMzBkOS00MTNmLTg5ZDQtZjY5Njk4Njk2MmRlXkEyXkFqcGdeQXVyNjc1NTYyMjg@._V1_.jpg",
      description:
        "Rudy has always been told that he was too small to play college football. But he is determined to overcome the odds and fulfill his dream of playing for Notre Dame.",
      rating: 7.5,
      genres: %w[Biography Drama Sport],
      duration: "01:54",
    }
  end
end
