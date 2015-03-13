require "spec_helper"

describe Onebox::Engine::GoogleDocsOnebox do
  context "Spreadsheets" do
    let(:matcher) { described_class.new("https://docs.google.com/spreadsheets/d/SHEET_KEY/pubhtml") }

    it "should have spreadsheet class in html" do
      expect(matcher.to_html).to include "spreadsheet-onebox"
    end

    it "should be a spreadsheet" do
      expect(matcher.send(:spreadsheet?)).to be true
    end

    it "Should detect key" do
      expect(matcher.send(:key)).to eq 'SHEET_KEY'
    end
  end

  context "Documents" do
    let(:matcher) { described_class.new("https://docs.google.com/document/d/DOC_KEY/pub") }

    it "should have document class in html" do
      expect(matcher.to_html).to include "document-onebox"
    end

    it "should be a document" do
      expect(matcher.send(:document?)).to be true
    end

    it "Should detect key" do
      expect(matcher.send(:key)).to eq 'DOC_KEY'
    end
  end

  context "Presentaions" do
    let(:matcher) { described_class.new("https://docs.google.com/presentation/d/PRESENTATION_KEY/pub") }

    it "should have presentation class in html" do
      expect(matcher.to_html).to include "presentation-onebox"
    end

    it "should be a presentation" do
      expect(matcher.send(:presentation?)).to be true
    end

    it "Should detect key" do
      expect(matcher.send(:key)).to eq 'PRESENTATION_KEY'
    end
  end

  context "Forms" do
    let(:matcher) { described_class.new("https://docs.google.com/forms/d/FORMS_KEY/viewform") }

    it "should have forms class in html" do
      expect(matcher.to_html).to include "forms-onebox"
    end

    it "should be a form" do
      expect(matcher.send(:forms?)).to be true
    end

    it "Should detect key" do
      expect(matcher.send(:key)).to eq 'FORMS_KEY'
    end
  end
end
