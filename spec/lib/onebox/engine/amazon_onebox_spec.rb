require "spec_helper"

describe Onebox::Engine::AmazonOnebox do
  before(:all) do
    @link = "http://www.amazon.com/Knit-Noro-Accessories-Colorful-Little/dp/193609620X"
    @uri = "http://www.amazon.com/gp/aw/d/193609620X"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "works with international domains" do

    def check_link(tdl, link)
      onebox_cls = Onebox::Matcher.new(link).oneboxed
      expect(onebox_cls).to_not be(nil)
      expect(onebox_cls.new(link).url).to include("http://www.amazon.#{tdl}")
    end

    it "matches canadian domains" do
      resp = check_link("ca", "http://www.amazon.ca/Too-Much-Happiness-Alice-Munro-ebook/dp/B0031TZ98K/")

    end

    it "matches german domains" do
      check_link("de", "http://www.amazon.de/Buddenbrooks-Verfall-einer-Familie-Roman/dp/3596294312/")
    end

    it "matches uk domains" do
      check_link("co.uk", "http://www.amazon.co.uk/Pygmalion-George-Bernard-Shaw/dp/1420925237/")
    end

    it "matches japanese domains" do
      check_link("co.jp", "http://www.amazon.co.jp/%E9%9B%AA%E5%9B%BD-%E6%96%B0%E6%BD%AE%E6%96%87%E5%BA%AB-%E3%81%8B-1-1-%E5%B7%9D%E7%AB%AF-%E5%BA%B7%E6%88%90/dp/4101001014/")
    end

    it "matches chinese domains" do
      check_link("cn", "http://www.amazon.cn/%E5%AD%99%E5%AD%90%E5%85%B5%E6%B3%95-%E5%AD%99%E8%86%91%E5%85%B5%E6%B3%95-%E5%AD%99%E6%AD%A6/dp/B0011C40FC/")
    end

    it "matches french domains" do
      check_link("fr", "http://www.amazon.fr/Les-Mots-autres-%C3%A9crits-autobiographiques/dp/2070114147/")
    end

    it "matches italian domains" do
      check_link("it", "http://www.amazon.it/Tutte-poesie-Salvatore-Quasimodo/dp/8804520477/")
    end

    it "matches spanish domains" do
      check_link("es", "http://www.amazon.es/familia-Pascual-Duarte-Camilo-Jos%C3%A9-ebook/dp/B00EJRTKTW/")
    end

    it "matches brasilian domains" do
      check_link("com.br", "http://www.amazon.com.br/A-p%C3%A1tria-chuteiras-Nelson-Rodrigues-ebook/dp/B00J2B414Y/")
    end

    it "matches indian domains" do
      check_link("in", "http://www.amazon.in/Fireflies-Rabindranath-Tagore/dp/9381523169/")
    end

  end

  describe "#to_html" do
    it "includes image" do
      expect(html).to include("img")
    end

    it "includes description" do
      expect(html).to include("Using only the finest natural materials and ecologically sound")
    end

  end
end
