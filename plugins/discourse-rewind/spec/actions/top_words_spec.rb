# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::TopWords do
  fab!(:date) { Date.new(2021).all_year }
  fab!(:user)
  fab!(:other_user, :user)

  fab!(:post1) do
    Fabricate(
      :post,
      user: user,
      raw: "apple orange banana apple apple orange",
      created_at: random_datetime,
    )
  end
  fab!(:post2) do
    Fabricate(:post, user: user, raw: "cucumber tomato banana orange", created_at: random_datetime)
  end
  fab!(:post3) do
    Fabricate(:post, user: user, raw: "grape watermelon mango", created_at: random_datetime)
  end
  fab!(:post4) do
    Fabricate(:post, user: user, raw: "apple banana grape apple", created_at: random_datetime)
  end
  fab!(:post5) do
    Fabricate(:post, user: user, raw: "apple orange apple apple", created_at: random_datetime)
  end
  fab!(:other_user_post) do
    Fabricate(:post, user: other_user, raw: "apple apple apple", created_at: random_datetime)
  end

  before do
    SearchIndexer.enable
    [post1, post2, post3, post4, post5, other_user_post].each do |post|
      SearchIndexer.index(post, force: true)
    end
  end

  describe ".call" do
    it "limits top words to 5" do
      result = call_report

      expect(result[:data].length).to eq(5)
    end

    it "returns top words ordered by frequency" do
      result = call_report

      expect(result[:identifier]).to eq("top-words")

      words = result[:data]

      expect(words.first[:word]).to eq("apple")
      expect(words.second[:word]).to eq("orange")
      expect(words.third[:word]).to eq("banana")

      expect(words.map { |w| w[:word] }).to include("apple", "orange", "banana", "grape")
      expect(words.map { |w| w[:score] }).to eq(words.map { |w| w[:score] }.sort.reverse)
    end

    context "when a post is deleted" do
      before do
        post1.trash!(Discourse.system_user)
        post1.post_search_data.destroy!
      end

      it "does not include words from deleted posts" do
        result = call_report

        words = result[:data]

        apple = words.find { |w| w[:word] == "apple" }
        expect(apple[:score]).to be < 9
      end
    end

    context "when posts are from another user" do
      it "does not include words from other users' posts" do
        result = call_report

        words = result[:data]
        apple_score = words.find { |w| w[:word] == "apple" }[:score]

        expect(apple_score).to be < 12
      end
    end

    context "with a large number of posts and words" do
      before do
        # Create posts with different frequencies of non-stop words
        10.times do |i|
          post =
            Fabricate(
              :post,
              user: user,
              raw: "#{frequent_word} #{frequent_word} #{frequent_word} #{infrequent_word}",
              created_at: random_datetime,
            )
          SearchIndexer.index(post, force: true)
        end
      end

      let(:frequent_word) { "zucchini" }
      let(:infrequent_word) { "xylophone" }

      it "ranks high frequency words higher than low frequency words" do
        result = call_report

        words = result[:data]
        frequent_word_entry = words.find { |w| w[:word] == frequent_word }
        infrequent_word_entry = words.find { |w| w[:word] == infrequent_word }

        expect(frequent_word_entry).to be_present
        expect(infrequent_word_entry).to be_present

        expect(frequent_word_entry[:score]).to be > infrequent_word_entry[:score]
      end
    end
  end

  context "when in rails development mode" do
    before { Rails.env.stubs(:development?).returns(true) }

    it "returns fake data" do
      result = call_report

      expect(result[:identifier]).to eq("top-words")
      expect(result[:data].length).to eq(5)
      expect(result[:data].first[:word]).to eq("seven")
      expect(result[:data].first[:score]).to eq(100)
      expect(result[:data].second[:word]).to eq("longest")
      expect(result[:data].second[:score]).to eq(90)
    end
  end
end
