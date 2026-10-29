# frozen_string_literal: true

RSpec.describe Onebox::Engine::StackExchangeOnebox do
  describe "domains" do
    shared_examples "stack exchange onebox for domain" do |domain|
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

    include_examples "stack exchange onebox for domain", "stackoverflow.com"
    include_examples "stack exchange onebox for domain", "meta.stackoverflow.com"
    include_examples "stack exchange onebox for domain", "superuser.com"
    include_examples "stack exchange onebox for domain", "meta.superuser.com"
    include_examples "stack exchange onebox for domain", "serverfault.com"
    include_examples "stack exchange onebox for domain", "meta.serverfault.com"
    include_examples "stack exchange onebox for domain", "askubuntu.com"
    include_examples "stack exchange onebox for domain", "meta.askubuntu.com"
    include_examples "stack exchange onebox for domain", "mathoverflow.net"
    include_examples "stack exchange onebox for domain", "meta.mathoverflow.net"
    include_examples "stack exchange onebox for domain", "money.stackexchange.com"
    include_examples "stack exchange onebox for domain", "meta.money.stackexchange.com"
    include_examples "stack exchange onebox for domain", "stackapps.com"

    it "doesn't match question on example.com" do
      expect(described_class === URI("http://example.com/q/4711")).to eq(false)
    end

    it "doesn't match answer on example.com" do
      expect(described_class === URI("http://example.com/a/4711")).to eq(false)
    end
  end

  shared_examples "stack exchange onebox for name and url" do |name, url|
    describe "question with #{name}" do
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
  end

  include_examples "stack exchange onebox for name and url",
                   [
                     "long URL",
                     "http://stackoverflow.com/questions/17992553/concept-behind-these-four-lines-of-tricky-c-code",
                   ]
  include_examples "stack exchange onebox for name and url",
                   ["short URL", "http://stackoverflow.com/q/17992553"]

  shared_examples "stack exchange onebox for name and url (2)" do |name, url|
    describe "answer with #{name}" do
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
  end

  include_examples "stack exchange onebox for name and url (2)",
                   [
                     "long URL",
                     "http://stackoverflow.com/questions/17992553/concept-behind-these-four-lines-of-tricky-c-code/17992906#17992906",
                   ]
  include_examples "stack exchange onebox for name and url (2)",
                   ["short URL", "http://stackoverflow.com/a/17992906"]
end
