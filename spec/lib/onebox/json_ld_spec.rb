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

  it "returns an empty hash if the JSON-LD type is unsupported" do
    doc =
      Nokogiri.HTML(
        "<script type=\"application/ld+json\">{\"@type\":\"Something Else\",\"aggregateRating\":{\"@type\":\"AggregateRating\",\"ratingCount\":806928,\"bestRating\":10,\"worstRating\":1}}</script>",
      )
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq({})
  end

  it "normalizes Event data" do
    doc = Nokogiri.HTML(<<~HTML)
        <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "Event",
            "description": "Meet the community",
            "startDate": "2026-10-22T09:00:00-04:00",
            "endDate": "2026-10-22T10:00:00-04:00"
          }
        </script>
      HTML

    expect(described_class.new(doc).data).to eq(
      event_starts_at: "2026-10-22T09:00:00-04:00",
      event_ends_at: "2026-10-22T10:00:00-04:00",
      event_all_day: "false",
      event_description: "Meet the community",
    )
  end

  it "reads an Event image given as an ImageObject" do
    doc = Nokogiri.HTML(<<~HTML)
        <script type="application/ld+json">
          {
            "@type": "Event",
            "startDate": "2026-10-22",
            "image": { "@type": "ImageObject", "url": "https://example.com/event.png", "width": 800, "height": 600 }
          }
        </script>
      HTML

    expect(described_class.new(doc).data).to include(
      event_image: "https://example.com/event.png",
      event_image_width: "800",
      event_image_height: "600",
    )
  end

  it "reads the first of several Event images given as URLs" do
    doc = Nokogiri.HTML(<<~HTML)
        <script type="application/ld+json">
          {
            "@type": "Event",
            "startDate": "2026-10-22",
            "image": ["https://example.com/first.png", "https://example.com/second.png"]
          }
        </script>
      HTML

    expect(described_class.new(doc).data).to include(event_image: "https://example.com/first.png")
    expect(described_class.new(doc).data).not_to have_key(:event_image_width)
  end

  it "recognizes date-only Events as all-day" do
    doc = Nokogiri.HTML(<<~HTML)
        <script type="application/ld+json">
          { "@context": "https://schema.org", "@type": "Event", "startDate": "2026-10-22" }
        </script>
      HTML

    expect(described_class.new(doc).data).to include(event_all_day: "true")
  end

  it "does not treat invalid Event dates as all-day" do
    doc = Nokogiri.HTML(<<~HTML)
        <script type="application/ld+json">
          { "@context": "https://schema.org", "@type": "Event", "startDate": "not-a-date" }
        </script>
      HTML

    expect(described_class.new(doc).data).to include(event_all_day: "false")
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
