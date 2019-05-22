# frozen_string_literal: true

require "spec_helper"

describe Onebox::Engine::AmazonOnebox do

  context "regular amazon page" do
    before do
      @link = "https://www.amazon.com/Knit-Noro-Accessories-Colorful-Little/dp/193609620X"
      @uri = "https://www.amazon.com/gp/aw/d/193609620X"
    end
    include_context "engines"
    it_behaves_like "an engine"

    describe "works with international domains" do

      def check_link(tdl, link)
        onebox_cls = Onebox::Matcher.new(link).oneboxed
        expect(onebox_cls).to_not be(nil)
        expect(onebox_cls.new(link).url).to include("https://www.amazon.#{tdl}")
      end

      it "matches canadian domains" do
        check_link("ca", "https://www.amazon.ca/Too-Much-Happiness-Alice-Munro-ebook/dp/B0031TZ98K/")
      end

      it "matches german domains" do
        check_link("de", "https://www.amazon.de/Buddenbrooks-Verfall-einer-Familie-Roman/dp/3596294312/")
      end

      it "matches uk domains" do
        check_link("co.uk", "https://www.amazon.co.uk/Pygmalion-George-Bernard-Shaw/dp/1420925237/")
      end

      it "matches japanese domains" do
        check_link("co.jp", "https://www.amazon.co.jp/%E9%9B%AA%E5%9B%BD-%E6%96%B0%E6%BD%AE%E6%96%87%E5%BA%AB-%E3%81%8B-1-1-%E5%B7%9D%E7%AB%AF-%E5%BA%B7%E6%88%90/dp/4101001014/")
      end

      it "matches chinese domains" do
        check_link("cn", "https://www.amazon.cn/%E5%AD%99%E5%AD%90%E5%85%B5%E6%B3%95-%E5%AD%99%E8%86%91%E5%85%B5%E6%B3%95-%E5%AD%99%E6%AD%A6/dp/B0011C40FC/")
      end

      it "matches french domains" do
        check_link("fr", "https://www.amazon.fr/Les-Mots-autres-%C3%A9crits-autobiographiques/dp/2070114147/")
      end

      it "matches italian domains" do
        check_link("it", "https://www.amazon.it/Tutte-poesie-Salvatore-Quasimodo/dp/8804520477/")
      end

      it "matches spanish domains" do
        check_link("es", "https://www.amazon.es/familia-Pascual-Duarte-Camilo-Jos%C3%A9-ebook/dp/B00EJRTKTW/")
      end

      it "matches brasilian domains" do
        check_link("com.br", "https://www.amazon.com.br/A-p%C3%A1tria-chuteiras-Nelson-Rodrigues-ebook/dp/B00J2B414Y/")
      end

      it "matches indian domains" do
        check_link("in", "https://www.amazon.in/Fireflies-Rabindranath-Tagore/dp/9381523169/")
      end

    end

    describe "#url" do
      it "maintains the same http/https scheme as the requested URL" do
        expect(described_class.new("https://www.amazon.fr/gp/product/B01BYD0TZM").url)
          .to eq("https://www.amazon.fr/gp/aw/d/B01BYD0TZM")

        expect(described_class.new("http://www.amazon.fr/gp/product/B01BYD0TZM").url)
          .to eq("https://www.amazon.fr/gp/aw/d/B01BYD0TZM")
      end
    end

    describe "#to_html" do
      it "includes image" do
        expect(html).to include("https://images-na.ssl-images-amazon.com/images/I/51opYcR6kVL._SY400_.jpg")
      end

      it "includes description" do
        expect(html).to include("You should learn a programming language every year, as recommended by The Pragmatic Programmer.")
      end

      it "includes price" do
        expect(html).to include("$21.11")
      end

      it "includes title" do
        expect(html).to include("Seven Languages in Seven Weeks: A Pragmatic Guide to Learning Programming Languages (Pragmatic Programmers)")
      end
    end
  end

  context "amazon with opengraph" do
    let(:link) { "https://www.amazon.com/dp/B01MFXN4Y2" }
    let(:html) { described_class.new(link).to_html }

    before do
      fake("https://www.amazon.com/gp/aw/d/B01MFXN4Y2", response("amazon-og"))
    end

    describe "#to_html" do
      it "includes image" do
        expect(html).to include("https://images-na.ssl-images-amazon.com/images/I/51nOF2iBa6L._SX940_.jpg")
      end

      it "includes description" do
        expect(html).to include("CHRISTINE is the story of an aspiring newswoman caught in the midst of a personal and professional life crisis. Between unrequited love, frustration at work, a tumultuous home, and self-doubt; she begins to spiral down a dark path.")
      end

      it "includes title" do
        expect(html).to include("Watch Christine online - Amazon Video")
      end
    end
  end

  context "amazon book page" do
    let(:link) { "https://www.amazon.com/dp/B00AYQNR46" }
    let(:html) { described_class.new(link).to_html }

    before do
      fake("https://www.amazon.com/gp/aw/d/B00AYQNR46", response("amazon"))
    end

    describe "#to_html" do
      it "includes title and author" do
        expect(html).to include("Seven Languages in Seven Weeks: A Pragmatic Guide to Learning Programming Languages (Pragmatic Programmers)")
        expect(html).to include("Bruce Tate")
      end

      it "includes ISBN" do
        expect(html).to include("978-1934356593")
      end

      it "includes publisher" do
        expect(html).to include("Pragmatic Bookshelf")
      end
    end
  end

  context "amazon ebook page" do
    let(:link) { "https://www.amazon.com/dp/193435659X" }
    let(:html) { described_class.new(link).to_html }

    before do
      fake("https://www.amazon.com/gp/aw/d/193435659X", response("amazon-ebook"))
    end

    describe "#to_html" do
      it "includes title and author" do
        expect(html).to include("Seven Languages in Seven Weeks: A Pragmatic Guide to Learning Programming Languages (Pragmatic Programmers)")
        expect(html).to include("Bruce Tate")
      end

      it "includes image" do
        expect(html).to include("https://images-na.ssl-images-amazon.com/images/I/51LZT%2BtSrTL._SX133_.jpg")
      end

      it "includes ASIN" do
        expect(html).to include("B00AYQNR46")
      end

      it "includes rating" do
        expect(html).to include("4.2 out of 5 stars")
      end

      it "includes publisher" do
        expect(html).to include("Pragmatic Bookshelf")
      end
    end
  end

end
