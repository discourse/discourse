require "spec_helper"

describe Onebox::Engine::Wikipedia do
  describe "to_html" do
    let(:link) { "http://example.com" }

    it "returns the product URL" do
      wikipedia = described_class.new(response("wikipedia.response"), link)
      expect(wikipedia.to_html).to include(link)
    end

    it "returns the article title" do
      wikipedia = described_class.new(response("wikipedia.response"), link)
      expect(wikipedia.to_html).to include("Kevin Bacon")
    end

    it "returns the article img src" do
      wikipedia = described_class.new(response("wikipedia.response"), link)
      expect(wikipedia.to_html).to include("//upload.wikimedia.org/wikipedia/commons/thumb/7/78/Kevin_Bacon_Comic-Con_2012.jpg/225px-Kevin_Bacon_Comic-Con_2012.jpg")
    end

    it "returns the article summary" do
      wikipedia = described_class.new(response("wikipedia.response"), link)
      expect(wikipedia.to_html).to include("Kevin Norwood Bacon[1] (born July 8, 1958) is an American actor and musician " +
                                           "whose notable roles include National Lampoon's Animal House, Diner, Footloose, " +
                                           "Flatliners, Wild Things, A Few Good Men, JFK, The River Wild, Murder in the " +
                                           "First, Apollo 13, Hollow Man, Stir of Echoes, Trapped, Mystic River, The Woodsman, " +
                                           "Friday the 13th, Death Sentence, Frost/Nixon, X-Men: First Class, and Tremors. " +
                                           "He currently stars on the Fox television series The Following.")
    end
  end
end
