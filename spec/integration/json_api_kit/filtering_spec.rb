# frozen_string_literal: true

require_relative "support"

RSpec.describe "a filtered listing" do
  include_context "with a listing of topics"

  let(:params) { { filter: { title: middle.title } } }

  it "keeps the rows the filter allows" do
    expect(document).to eq(data: [topic_object(middle)], included: [], links: links_of)
  end

  context "when the filter keeps no row" do
    let(:params) { { filter: { title: "No topic carries this title" } } }

    it "returns an empty listing" do
      expect(document).to eq(data: [], included: [], links: links_of)
    end
  end

  context "when the filter value is a list" do
    let(:params) { { sort: { created_at: :asc }, filter: { title: [oldest.title, newest.title] } } }

    it "keeps a row for each value of the list" do
      expect(document).to eq(
        data: [topic_object(oldest), topic_object(newest)],
        included: [],
        links: links_of,
      )
    end
  end
end
