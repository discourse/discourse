# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::PubmedOnebox do
  let(:link) { "http://www.ncbi.nlm.nih.gov/pubmed/7288891" }
  let(:xml_link) { "http://www.ncbi.nlm.nih.gov/pubmed/7288891?report=xml&format=text" }
  let(:html) { described_class.new(link).to_html }

  before do
    stub_request(:get, link).to_return(status: 200, body: onebox_response("pubmed"))
    stub_request(:get, xml_link).to_return(status: 200, body: onebox_response("pubmed-xml"))
  end

  it "has the paper's title" do
    expect(html).to include("Evolutionary trees from DNA sequences: a maximum likelihood approach.")
  end

  it "has the paper's author" do
    expect(html).to include("Felsenstein")
  end

  it "has the paper's abstract" do
    expect(html).to include("The application of maximum likelihood techniques to the estimation of evolutionary trees from nucleic acid sequence data is discussed.") end

  it "has the paper's date" do
    expect(html).to include("1981")
  end

  it "has the URL to the resource" do
    expect(html).to include(link)
  end

  context "Pubmed electronic print" do
    let(:link) { "http://www.ncbi.nlm.nih.gov/pubmed/24737116" }
    let(:xml_link) { "http://www.ncbi.nlm.nih.gov/pubmed/24737116?report=xml&format=text" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:get, link).to_return(status: 200, body: onebox_response("pubmed-electronic"))
      stub_request(:get, xml_link).to_return(status: 200, body: onebox_response("pubmed-electronic-xml"))
    end

    it "has the paper's title" do
      expect(html).to include("Cushingoid facies on (18)F-FDG PET/CT.")
    end

    it "has the paper's author" do
      expect(html).to include("van Rheenen")
    end

    it "has the paper's date" do
      expect(html).to include("Jul 2014")
    end

    it "has the URL to the resource" do
      expect(html).to include(link)
    end
  end

  context "regex URI match" do
    it "matches on specific articles" do
      expect(match("http://www.ncbi.nlm.nih.gov/pubmed/7288891")).to eq true
    end

    it "does not match on search" do
      expect(match("http://www.ncbi.nlm.nih.gov/pubmed/?term=rheenen+r")).to eq false
    end

    it "does not match on the root" do
      expect(match("http://www.ncbi.nlm.nih.gov/pubmed/")).to eq false
    end

    def match(url)
      Onebox::Engine::PubmedOnebox === URI(url)
    end
  end
end
