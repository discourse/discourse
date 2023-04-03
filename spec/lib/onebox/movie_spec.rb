# frozen_string_literal: true

require "onebox/movie"

RSpec.describe Onebox::Movie do
  it "returns a nil rating if there is no aggregateRating item in json_ld data" do
    json_ld_data =
      json_ld_data_from_doc(
        "<script type=\"application/ld+json\">{\"@type\":\"Movie\",\"someKey\":{}}</script>",
      )
    json_ld = described_class.new(json_ld_data)
    expect(json_ld.rating).to eq(nil)
  end

  it "returns a nil rating if there is no ratingValue item in json_ld data" do
    json_ld_data =
      json_ld_data_from_doc(
        "<script type=\"application/ld+json\">{\"@type\":\"Movie\",\"aggregateRating\":{\"@type\":\"AggregateRating\",\"ratingCount\":806928,\"bestRating\":10,\"worstRating\":1}}</script>",
      )
    json_ld = described_class.new(json_ld_data)
    expect(json_ld.rating).to eq(nil)
  end

  it "returns a nil if there is no duration in json_ld data" do
    json_ld_data =
      json_ld_data_from_doc(
        "<script type=\"application/ld+json\">{\"@type\":\"Movie\",\"aggregateRating\":{\"@type\":\"AggregateRating\",\"ratingCount\":806928,\"bestRating\":10,\"worstRating\":1}}</script>",
      )
    json_ld = described_class.new(json_ld_data)
    expect(json_ld.duration).to eq(nil)
  end

  it "to_h returns hash version of the object" do
    json_ld_data = json_ld_data_from_doc(onebox_response("imdb"))
    movie = described_class.new(json_ld_data)
    expect(movie.to_h).to eq(expected_movie_hash)
  end

  private

  def json_ld_data_from_doc(html)
    JSON[Nokogiri.HTML(html).search('script[type="application/ld+json"]').text]
  end

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
