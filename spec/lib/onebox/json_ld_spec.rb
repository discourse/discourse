# frozen_string_literal: true

require 'onebox/json_ld'

describe Onebox::JsonLd do
  it 'logs warning and returns an empty hash if received json is invalid' do
    invalid_json = "{\"@type\":invalid-json}"
    doc = Nokogiri::HTML("<script type=\"application/ld+json\">#{invalid_json}</script>")
    Discourse.expects(:warn_exception).with(
      instance_of(JSON::ParserError), { message: "Error parsing JSON-LD json: #{invalid_json}" }
    )

    json_ld = described_class.new(doc)

    expect(json_ld.data).to eq({})
  end

  it 'returns an empty hash if there is no json_ld script tag' do
    doc = Nokogiri::HTML("<script type=\"something else\"></script>")
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq({})
  end

  it 'returns an empty hash if there is no json_ld data' do
    doc = Nokogiri::HTML("<script type=\"application/ld+json\"></script>")
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq({})
  end

  it 'returns an empty hash if the type of JSONLD data is not Movie' do
    doc = Nokogiri::HTML("<script type=\"application/ld+json\">{\"@type\":\"Something Else\",\"aggregateRating\":{\"@type\":\"AggregateRating\",\"ratingCount\":806928,\"bestRating\":10,\"worstRating\":1}}</script>")
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq({})
  end

  it 'correctly normalizes the properties' do
    doc = Nokogiri::HTML(onebox_response('imdb'))
    json_ld = described_class.new(doc)
    expect(json_ld.data).to eq(expected_movie_hash)
  end

  private

  def expected_movie_hash
    {
      name: 'Rudy',
      image: 'https://m.media-amazon.com/images/M/MV5BZGUzMDU1YmQtMzBkOS00MTNmLTg5ZDQtZjY5Njk4Njk2MmRlXkEyXkFqcGdeQXVyNjc1NTYyMjg@._V1_.jpg',
      description: 'Rudy has always been told that he was too small to play college football. But he is determined to overcome the odds and fulfill his dream of playing for Notre Dame.',
      rating: 7.5,
      genres: ['Biography', 'Drama', 'Sport'],
      duration: '01:54'
    }
  end
end
