# frozen_string_literal: true

RSpec.describe TopicRetriever do
  let(:embed_url) { "http://eviltrout.com/2013/02/10/why-discourse-uses-emberjs.html" }
  let(:topic_retriever) { TopicRetriever.new(embed_url) }

  it "can initialize without optional parameters" do
    t = TopicRetriever.new(embed_url)
    expect(t).to be_present
  end

  describe "#retrieve" do
    context "when host is invalid" do
      before { topic_retriever.stubs(:invalid_url?).returns(true) }

      it "does not perform_retrieve" do
        topic_retriever.expects(:perform_retrieve).never
        topic_retriever.retrieve
      end
    end

    context "when topics have been retrieved recently" do
      before { topic_retriever.stubs(:retrieved_recently?).returns(true) }

      it "does not perform_retrieve" do
        topic_retriever.expects(:perform_retrieve).never
        topic_retriever.retrieve
      end
    end

    context "when host is valid" do
      before { Fabricate(:embeddable_host, host: "http://eviltrout.com/") }

      context "when topics have been retrieved recently" do
        before { topic_retriever.stubs(:retrieved_recently?).returns(true) }

        it "does not perform_retrieve" do
          topic_retriever.expects(:perform_retrieve).never
          topic_retriever.retrieve
        end
      end

      context "when topics have not been retrieved recently" do
        before { topic_retriever.stubs(:retrieved_recently?).returns(false) }

        it "does perform_retrieve" do
          topic_retriever.expects(:perform_retrieve).once
          topic_retriever.retrieve
        end
      end
    end

    context "when host is invalid" do
      before { Fabricate(:embeddable_host, host: "http://not-eviltrout.com/") }

      it "does not perform_retrieve" do
        topic_retriever.expects(:perform_retrieve).never
        topic_retriever.retrieve
      end
    end

    it "works with URLs with whitespaces" do
      expect { TopicRetriever.new(" https://example.com ").retrieve }.not_to raise_error
    end
  end
end
