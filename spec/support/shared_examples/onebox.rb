# frozen_string_literal: true

RSpec.shared_context "with engines" do
  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data).deep_symbolize_keys }
  let(:link) { @link }
  let(:uri) { defined?(@uri) ? @uri : link }

  before do
    fixture = defined?(@onebox_fixture) ? @onebox_fixture : described_class.onebox_name
    stub_request(:get, uri).to_return(status: 200, body: onebox_response(fixture))
  end
end

RSpec.shared_examples_for "an engine" do
  it "responds to data" do
    expect(described_class.private_instance_methods).to include(:data)
  end

  it "correctly matches the url" do
    onebox = Onebox::Matcher.new(link, { allowed_iframe_regexes: [/.*/] }).oneboxed
    expect(onebox).to be(described_class)
  end

  describe "#data" do
    it "includes title" do
      expect(data[:title]).not_to be_nil
    end

    it "includes link" do
      expect(data[:link]).not_to be_nil
    end

    it "is serializable" do
      expect { Marshal.dump(data) }.to_not raise_error
    end
  end
end

RSpec.shared_examples_for "a layout engine" do
  describe "#to_html" do
    it "includes subname" do
      expect(html).to include(%|<aside class="onebox #{described_class.onebox_name}">|)
    end

    it "includes title" do
      expect(html).to include(data[:title])
    end

    it "includes link" do
      expect(html).to include(%|class="link" href="#{data[:link]}|)
    end

    it "includes badge" do
      expect(html).to include(%|<strong class="name">#{data[:badge]}</strong>|)
    end

    it "includes domain" do
      expect(html).to include(%|class="domain" href="#{data[:domain]}|)
    end
  end
end
