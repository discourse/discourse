# frozen_string_literal: true

RSpec.describe Onebox::Engine::AmazonOnebox do
  describe "#url" do
    it "normalizes product URLs" do
      {
        "https://www.amazon.ca/Too-Much-Happiness-Alice-Munro-ebook/dp/B0031TZ98K/" =>
          "https://www.amazon.ca/dp/B0031TZ98K",
        "https://www.amazon.de/Buddenbrooks-Verfall-einer-Familie-Roman/dp/3596294312/" =>
          "https://www.amazon.de/dp/3596294312",
        "https://www.amazon.co.uk/Pygmalion-George-Bernard-Shaw/dp/1420925237/" =>
          "https://www.amazon.co.uk/dp/1420925237",
        "https://www.amazon.co.jp/%E9%9B%AA%E5%9B%BD-%E6%96%B0%E6%BD%AE%E6%96%87%E5%BA%AB-%E3%81%8B-1-1-%E5%B7%9D%E7%AB%AF-%E5%BA%B7%E6%88%90/dp/4101001014/" =>
          "https://www.amazon.co.jp/dp/4101001014",
        "https://www.amazon.cn/%E5%AD%99%E5%AD%90%E5%85%B5%E6%B3%95-%E5%AD%99%E8%86%91%E5%85%B5%E6%B3%95-%E5%AD%99%E6%AD%A6/dp/B0011C40FC/" =>
          "https://www.amazon.cn/dp/B0011C40FC",
        "https://www.amazon.fr/Les-Mots-autres-%C3%A9crits-autobiographiques/dp/2070114147/" =>
          "https://www.amazon.fr/dp/2070114147",
        "https://www.amazon.it/Tutte-poesie-Salvatore-Quasimodo/dp/8804520477/" =>
          "https://www.amazon.it/dp/8804520477",
        "https://www.amazon.es/familia-Pascual-Duarte-Camilo-Jos%C3%A9-ebook/dp/B00EJRTKTW/" =>
          "https://www.amazon.es/dp/B00EJRTKTW",
        "https://www.amazon.com.br/A-p%C3%A1tria-chuteiras-Nelson-Rodrigues-ebook/dp/B00J2B414Y/" =>
          "https://www.amazon.com.br/dp/B00J2B414Y",
        "https://www.amazon.in/Fireflies-Rabindranath-Tagore/dp/9381523169/" =>
          "https://www.amazon.in/dp/9381523169",
        "https://www.amazon.com.mx/Legend-Zelda-Links-Awakening-Nintendo/dp/B07SG15148/" =>
          "https://www.amazon.com.mx/dp/B07SG15148",
        "http://www.amazon.fr/gp/product/B01BYD0TZM" => "https://www.amazon.fr/dp/B01BYD0TZM",
        "https://www.amazon.ca/gp/product/B087Z3N428?pf_rd_r=SXABADD0ZZ3NF9Q5F8TW&ref_=pd_gw_unk" =>
          "https://www.amazon.ca/dp/B087Z3N428",
      }.each do |link, url|
        expect(Onebox::Matcher.new(link).oneboxed).to eq(described_class)
        expect(described_class.new(link).url).to eq(url)
      end
    end
  end

  describe "amazon book page" do
    before do
      @link = "https://www.amazon.com/Knit-Noro-Accessories-Colorful-Little/dp/193609620X"
      @uri = "https://www.amazon.com/dp/193609620X"
    end

    include_context "with engines"
    it_behaves_like "an engine"

    it "renders the book details" do
      expect(html).to include(
        %(href="https://www.amazon.com/dp/193609620X"),
        "https://images-na.ssl-images-amazon.com/images/I/51opYcR6kVL._SY400_.jpg",
        "Seven Languages in Seven Weeks: A Pragmatic Guide to Learning Programming Languages (Pragmatic Programmers)",
        "Bruce Tate",
        "You should learn a programming language every year, as recommended by The Pragmatic Programmer.",
        "978-1934356593",
        "Pragmatic Bookshelf",
        "$21.11",
      )
    end
  end

  describe "amazon ebook page" do
    let(:link) { "https://www.amazon.com/dp/193435659X" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:get, link).to_return(status: 200, body: onebox_response("amazon-ebook"))
    end

    it "renders the ebook details" do
      expect(html).to include(
        "https://images-na.ssl-images-amazon.com/images/I/51LZT%2BtSrTL._SX133_.jpg",
        "Seven Languages in Seven Weeks: A Pragmatic Guide to Learning Programming Languages (Pragmatic Programmers)",
        "Bruce Tate",
        "4.2 out of 5 stars",
        "B00AYQNR46",
        "Pragmatic Bookshelf",
      )
    end
  end

  describe "amazon with opengraph" do
    let(:link) { "https://www.amazon.com/dp/B01MFXN4Y2" }
    let(:html) { described_class.new(link).to_html }

    before { stub_request(:get, link).to_return(status: 200, body: onebox_response("amazon-og")) }

    it "renders the product details" do
      expect(html).to include(
        "https://images-na.ssl-images-amazon.com/images/I/51nOF2iBa6L._SX940_.jpg",
        "Watch Christine online & foobar - Amazon Video",
        "CHRISTINE is the story of an aspiring newswoman caught in the midst of a personal and professional life crisis. Between unrequited love, frustration at work, a tumultuous home, and self-doubt; she begins to spiral down a dark path.",
      )
    end
  end

  describe "alternate page layout response from Amazon" do
    let(:link) { "https://www.amazon.com/dp/B07FQ7M16H" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:get, link).to_return(status: 200, body: onebox_response("amazon-alternate"))
    end

    it "renders the product details" do
      expect(html).to include(
        %(href="https://www.amazon.com/Lnchett-Nibbler-Quality-Attachment-Straight/dp/B07FQ7M16H"),
        "https://m.media-amazon.com/images/I/71y4BRqNP7L._AC_SL1500_.jpg",
        "Quality Nibbler Drill Attachment...",
        "Drill Attachment for Straight Curve and Circle Cutting, Maximum 14 Gauge Steel",
        "$37.99",
      )
    end
  end

  describe "product page with a canonical link to another page" do
    let(:link) { "https://www.amazon.com/dp/B082SBHKN2" }
    let(:image) { "https://m.media-amazon.com/images/I/71-EGU00XgL.jpg" }
    let(:html) { described_class.new(link).to_html }

    before do
      stub_request(:get, link).to_return(
        status: 200,
        body:
          "<html><head><title>SwiftJet Car Wash Foam Gun</title><meta name='description' content='Foam gun'><link rel='canonical' href='https://www.amazon.com/clp/B082SBHKN2'></head><body><img id='landingImage' data-old-hires='' src='#{image}'></body></html>",
      )

      stub_request(:get, "https://www.amazon.com/clp/B082SBHKN2").to_return(
        status: 200,
        body: "<html><body><svg><title>open prime modal</title></svg></body></html>",
      )
    end

    it "renders the product page" do
      expect(html).to include("SwiftJet Car Wash Foam Gun", %(href="#{link}"), %(src="#{image}"))
    end
  end

  describe "non-standard response from Amazon" do
    let(:link) { "https://www.amazon.com/dp/B0123ABCD3210" }
    let(:onebox) { described_class.new(link) }

    before do
      stub_request(:get, link).to_return(status: 200, body: onebox_response("amazon-error"))
    end

    it "returns a blank result with errors and a placeholder" do
      expect(onebox.to_html).to eq("")
      expect(onebox.errors).to eq({ title: ["is blank"], description: ["is blank"] })
      expect(onebox.placeholder_html).to include(
        %(<aside class="onebox amazon" data-onebox-src="#{link}">),
      )
    end
  end
end
