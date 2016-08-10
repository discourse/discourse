require "spec_helper"

describe Onebox::Engine::GoogleDocsOnebox do
  context "Spreadsheets" do
    let(:matcher) { described_class.new("https://docs.google.com/spreadsheets/d/SHEET_KEY/pubhtml") }

    it "should be a spreadsheet" do
      expect(matcher.send(:shorttype)).to eq (:sheets)
    end
  end

  context "Documents" do
    let(:matcher) { described_class.new("https://docs.google.com/document/d/DOC_KEY/pub") }

    it "should be a document" do
      expect(matcher.send(:shorttype)).to eq (:docs)
    end
  end

  context "Presentaions" do
    let(:matcher) { described_class.new("https://docs.google.com/presentation/d/PRESENTATION_KEY/pub") }

    it "should be a presentation" do
      expect(matcher.send(:shorttype)).to eq (:slides)
    end
  end

  context "Forms" do
    let(:matcher) { described_class.new("https://docs.google.com/forms/d/FORMS_KEY/viewform") }

    it "should be a form" do
      expect(matcher.send(:shorttype)).to eq (:forms)
    end
  end
end
