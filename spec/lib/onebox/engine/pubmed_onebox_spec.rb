require "spec_helper"

describe Onebox::Engine::PubmedOnebox do

  let(:link) { "http://www.ncbi.nlm.nih.gov/pubmed/7288891" }
  let(:xml_link) { "http://www.ncbi.nlm.nih.gov/pubmed/7288891?report=xml&format=text" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("pubmed"))
    fake(xml_link, response("pubmed-xml"))
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
end

