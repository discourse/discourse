# frozen_string_literal: true

RSpec.describe Email::Receiver do
  describe "#select_body" do
    it "elides repeated Outlook signatures and their following elements" do
      signatures = '<div id="Signature"></div>' * 4000
      html = "<p>Body</p>" + signatures + "<p>Quote</p>"
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Quote")
    end

    it "elides repeated Outlook replies and their following elements" do
      signatures = '<div id="divRplyFwdMsg"></div>' * 4000
      html = "<p>Body</p>" + signatures + "<p>Quote</p>"
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Quote")
    end

    it "elides repeated Apple Mail signatures and their following elements" do
      signatures = '<div id="AppleMailSignature"></div>' * 4000
      html = "<p>Body</p>" + signatures + "<p>Quote</p>"
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Quote")
    end

    it "elides repeated Word signatures and their following elements" do
      signatures = "<div></div>" * 4000
      html = '<div class="WordSection1"><p>Body</p>' + signatures + "<p>Quote</p></div>"
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Quote")
    end

    it "elides repeated Mozilla citations and their following elements" do
      signatures = '<div class="moz-cite-prefix"></div>' * 4000
      html = "<p>Body</p>" + signatures + "<p>Quote</p>"
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Quote")
    end

    it "elides repeated Mozilla signatures and their following elements" do
      signatures = '<div class="moz-signature"></div>' * 4000
      html = "<p>Body</p>" + signatures + "<p>Quote</p>"
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Quote")
    end

    it "elides repeated Mozilla forwards and their following elements" do
      signatures = '<div class="moz-forward-container"></div>' * 4000
      html = "<p>Body</p>" + signatures + "<p>Quote</p>"
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Quote")
    end

    it "elides repeated Proton Mail signatures and their following elements" do
      signatures = '<div class="protonmail_signature_block"></div>' * 4000
      html = "<p>Body</p>" + signatures + "<p>Quote</p>"
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Quote")
    end

    it "preserves text siblings and content in independent containers" do
      html = <<~HTML
        <div><p>First body</p><div id="Signature">First signature</div>Keep text<p>First quote</p></div>
        <div><p>Second body</p><div id="Signature">Second signature</div><p>Second quote</p></div>
        <div><p>Third body</p></div>
      HTML
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("First body\n\nKeep text\n\nSecond body\n\nThird body")
      expect(elided).to eq("First signature\n\nFirst quote\n\nSecond signature\n\nSecond quote")
    end

    it "removes Outlook horizontal rules without eliding the content after them" do
      html = '<p>Body</p><hr><p>More body</p><div id="Signature">Signature</div><p>Quote</p>'
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body\n\nMore body")
      expect(elided).to eq("---\n\nSignature\n\nQuote")
    end

    it "keeps the first Apple Mail marker and elides elements following matching markers" do
      html = <<~HTML
        <p>Body</p>
        <div id="AppleMailSignature">First signature</div>
        <p>Keep this</p>
        <div id="AppleMailSignature">Last signature</div>
        <p>Quote</p>
      HTML
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body\n\nFirst signature")
      expect(elided).to eq("Keep this\n\nLast signature\n\nQuote")
    end

    it "preserves fragment selection order when a following sibling contains a signature" do
      html =
        '<p>Body</p><div id="Signature"><p>Signature</p></div><div><p>Quoted body</p><div id="Signature">Nested</div><p>Nested tail</p></div><p>Outside</p>'
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Signature\n\nQuoted body\n\nOutside\n\nNested\n\nNested tail")
    end

    it "preserves the order of nested trimmed elements" do
      html =
        '<p>Body</p><div id="Signature"><p>Signature</p><div id="Signature">Nested</div><p>Inside</p></div><p>Outside</p>'
      mail = "Content-Type: text/html; charset=UTF-8\r\n\r\n#{html}"

      body, elided = described_class.new(mail).select_body

      expect(body).to eq("Body")
      expect(elided).to eq("Signature\n\nNested\n\nInside\n\nOutside")
    end
  end
end
