# frozen_string_literal: true

RSpec.describe Onebox::Engine::StackExchangeOnebox do
  describe "domains" do
    shared_examples "a supported Stack Exchange domain" do |domain:|
      it "matches question with short URL on #{domain}" do
        expect(described_class === URI("http://#{domain}/q/55495")).to eq(true)
      end

      it "matches question with long URL on #{domain}" do
        expect(described_class === URI("http://#{domain}/questions/55495/title-of-question")).to eq(
          true,
        )
      end

      it "matches answer with short URL on #{domain}" do
        expect(described_class === URI("http://#{domain}/a/55503")).to eq(true)
      end

      it "matches an answer URL with a fragment on #{domain}" do
        expect(
          described_class === URI("http://#{domain}/questions/55495/title-of-question/55503#55503"),
        ).to eq(true)
      end
    end

    context "with the stackoverflow.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "stackoverflow.com"
    end

    context "with the meta.stackoverflow.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "meta.stackoverflow.com"
    end

    context "with the superuser.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "superuser.com"
    end

    context "with the meta.superuser.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "meta.superuser.com"
    end

    context "with the serverfault.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "serverfault.com"
    end

    context "with the meta.serverfault.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "meta.serverfault.com"
    end

    context "with the askubuntu.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "askubuntu.com"
    end

    context "with the meta.askubuntu.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "meta.askubuntu.com"
    end

    context "with the mathoverflow.net domain" do
      include_examples "a supported Stack Exchange domain", domain: "mathoverflow.net"
    end

    context "with the meta.mathoverflow.net domain" do
      include_examples "a supported Stack Exchange domain", domain: "meta.mathoverflow.net"
    end

    context "with the money.stackexchange.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "money.stackexchange.com"
    end

    context "with the meta.money.stackexchange.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "meta.money.stackexchange.com"
    end

    context "with the stackapps.com domain" do
      include_examples "a supported Stack Exchange domain", domain: "stackapps.com"
    end

    it "doesn't match question on example.com" do
      expect(described_class === URI("http://example.com/q/4711")).to eq(false)
    end

    it "doesn't match answer on example.com" do
      expect(described_class === URI("http://example.com/a/4711")).to eq(false)
    end
  end

  shared_examples "a Stack Exchange question URL" do |url:|
    before do
      @link = url

      stub_request(
        :get,
        "https://api.stackexchange.com/2.2/questions/17992553?site=stackoverflow.com&filter=!5-duuxrJa-iw9oVvOA(JNimB5VIisYwZgwcfNI",
      ).to_return(status: 200, body: onebox_response("stackexchange-question"))
    end

    include_context "with engines"
    it_behaves_like "an engine"

    describe "#to_html" do
      it "includes question title" do
        expect(html).to include("Concept behind these four lines of tricky C code")
      end

      it "includes 'asked by'" do
        expect(html).to include("asked by")
      end

      it "doesn't include 'answered by'" do
        expect(html).not_to include("answered by")
      end
    end
  end

  context "with a long question URL" do
    include_examples "a Stack Exchange question URL",
                     url:
                       "http://stackoverflow.com/questions/17992553/concept-behind-these-four-lines-of-tricky-c-code"
  end

  context "with a short question URL" do
    include_examples "a Stack Exchange question URL", url: "http://stackoverflow.com/q/17992553"
  end

  shared_examples "a Stack Exchange answer URL" do |url:|
    before do
      @link = url

      stub_request(
        :get,
        "https://api.stackexchange.com/2.2/answers/17992906?site=stackoverflow.com&filter=!.FjueITQdx6-Rq3Ue9PWG.QZ2WNdW",
      ).to_return(status: 200, body: onebox_response("stackexchange-answer"))
    end

    include_context "with engines"
    it_behaves_like "an engine"

    describe "#to_html" do
      it "includes question title" do
        expect(html).to include("Concept behind these four lines of tricky C code")
      end

      it "includes 'answered by'" do
        expect(html).to include("answered by")
      end

      it "doesn't include 'asked by'" do
        expect(html).not_to include("asked by")
      end
    end
  end

  context "with a long answer URL" do
    include_examples "a Stack Exchange answer URL",
                     url:
                       "http://stackoverflow.com/questions/17992553/concept-behind-these-four-lines-of-tricky-c-code/17992906#17992906"
  end

  context "with a short answer URL" do
    include_examples "a Stack Exchange answer URL", url: "http://stackoverflow.com/a/17992906"
  end
end
