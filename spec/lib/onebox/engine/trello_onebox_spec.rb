# frozen_string_literal: true

RSpec.describe Onebox::Engine::TrelloOnebox do
  describe "Boards" do
    it "should onebox with SEF url corrrectly" do
      expect(
        Onebox.preview("https://trello.com/b/nC8QJJoZ/trello-development-roadmap").to_s,
      ).to match('iframe src="https://trello.com/b/nC8QJJoZ.html"')
    end

    it "should onebox without SEF url corrrectly" do
      expect(Onebox.preview("https://trello.com/b/nC8QJJoZ/").to_s).to match(
        'iframe src="https://trello.com/b/nC8QJJoZ.html"',
      )

      # Without trailing slash
      expect(Onebox.preview("https://trello.com/b/nC8QJJoZ").to_s).to match(
        'iframe src="https://trello.com/b/nC8QJJoZ.html"',
      )
    end
  end

  describe "Cards" do
    it "should onebox with SEF url corrrectly" do
      expect(
        Onebox.preview(
          "https://trello.com/c/NIRpzVDM/1211-what-can-you-expect-from-this-board",
        ).to_s,
      ).to match('iframe src="https://trello.com/c/NIRpzVDM.html"')
    end

    it "should onebox without SEF url corrrectly" do
      expect(Onebox.preview("https://trello.com/c/NIRpzVDM/").to_s).to match(
        'iframe src="https://trello.com/c/NIRpzVDM.html"',
      )

      # Without trailing slash
      expect(Onebox.preview("https://trello.com/c/NIRpzVDM").to_s).to match(
        'iframe src="https://trello.com/c/NIRpzVDM.html"',
      )
    end
  end
end
