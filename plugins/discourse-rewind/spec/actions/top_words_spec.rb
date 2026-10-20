# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::TopWords do
  def index(post)
    SearchIndexer.index(post, force: true)
  end

  fab!(:user)
  fab!(:posts) do
    SearchIndexer.enable
    [
      "apple orange banana apple apple orange",
      "cucumber tomato banana orange",
      "grape watermelon mango",
      "apple banana grape apple",
      "apple orange apple apple",
    ].map do |raw|
      Fabricate(:post, user:, raw:, created_at: random_datetime).tap { |post| index(post) }
    end
  end

  before { SearchIndexer.enable }

  describe ".call" do
    it "returns the five most used words with their score" do
      expect(call_report).to eq(
        data: [
          { word: "apple", score: 11 },
          { word: "orange", score: 7 },
          { word: "banana", score: 6 },
          { word: "grape", score: 4 },
          { word: "cucumber", score: 2 },
        ],
        identifier: "top-words",
      )
    end

    it "shows the most used form of a word" do
      post = Fabricate(:post, user:, raw: "#{"releases " * 9}release", created_at: random_datetime)
      index(post)

      expect(call_report[:data].map { |word| word[:word] }).to include("releases")
    end

    it "counts the title of the user's own topics, but not of other people's" do
      own_topic = Fabricate(:topic, user:, title: "Everything about kiwi fruit")
      other_topic = Fabricate(:topic, title: "Everything about melon fruit")
      [own_topic, other_topic].each do |topic|
        post = Fabricate(:post, user:, topic:, raw: "kiwi melon " * 5, created_at: random_datetime)
        index(post)
      end
      reply = Fabricate(:post, user:, topic: own_topic, raw: "grape", created_at: random_datetime)
      index(reply)

      expect(call_report[:data].first(2)).to eq(
        [{ word: "kiwi", score: 13 }, { word: "melon", score: 12 }],
      )
    end

    it "ignores words that are only quoted or in code blocks" do
      raw = <<~RAW
        [quote="someone, post:1, topic:2"]
        quoted quoted quoted quoted
        [/quote]
        mine mine mine mine
        [quote="someone, post:1, topic:2"]
        quoted
        [/quote]
        ```
        codeword codeword codeword codeword
        ```
        lemon lemon lemon lemon
        ```
        codeword
        ```
      RAW
      post = Fabricate(:post, user:, raw:, created_at: random_datetime)
      index(post)

      words = call_report[:data].map { |word| word[:word] }

      expect(words).to include("mine", "lemon")
      expect(words).not_to include("quoted", "codeword")
    end

    it "ignores link and domain words" do
      post = Fabricate(:post, user:, raw: "github github github", created_at: random_datetime)
      index(post)

      expect(call_report[:data].map { |word| word[:word] }).not_to include("github")
    end

    it "uses the stemmer and accent handling of the site locale" do
      SiteSetting.default_locale = "fr"
      SiteSetting.search_ignore_accents = true
      raw = ("chevaux " * 20) + ("élèves " * 20)
      post = Fabricate(:post, user:, raw:, created_at: random_datetime)
      index(post)

      expect(call_report[:data].map { |word| word[:word] }).to include("chevaux", "élèves")
    end

    it "shows words from locales whose search data is segmented" do
      SiteSetting.default_locale = "ja"
      post = Fabricate(:post, user:, raw: "東京に行きました。" * 20, created_at: random_datetime)
      index(post)

      expect(call_report[:data].map { |word| word[:word] }).to include("まし")
    end

    it "ignores unstemmed words on English sites that segment Japanese" do
      SiteSetting.search_tokenize_japanese = true

      expect(call_report[:data].map { |word| word[:word] }).to eq(
        %w[apple orange banana grape cucumber],
      )
    end

    it "ignores quoted words on sites whose search data is not segmented" do
      SiteSetting.default_locale = "ko"
      raw = "[quote=\"someone, post:1, topic:2\"]\n#{"인용 " * 20}\n[/quote]\n#{"나의 " * 5}"
      post = Fabricate(:post, user:, raw:, created_at: random_datetime)
      index(post)

      expect(call_report[:data].map { |word| word[:word] }).to include("나의").and exclude("인용")
    end

    it "only counts words from the user's publicly visible posts" do
      raw = "confidential " * 10
      [
        Fabricate(:post, user:, raw: "pumpkin " * 10, created_at: random_datetime),
        Fabricate(:post, raw:, created_at: random_datetime),
        Fabricate(:private_message_post, user:, raw:, created_at: random_datetime),
      ].each { |post| index(post) }

      expect(call_report[:data].map { |word| word[:word] }).to contain_exactly(
        "apple",
        "orange",
        "banana",
        "grape",
        "pumpkin",
      )
    end
  end
end
