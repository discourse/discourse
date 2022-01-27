# frozen_string_literal: true

module OneboxHelpers
  def onebox_response(file)
    file = File.join("spec", "fixtures", "onebox", "#{file}.response")
    File.exist?(file) ? File.read(file) : ""
  end

  def inspect_html_fragment(raw_fragment, tag_name, attribute = 'src')
    preview = Nokogiri::HTML::DocumentFragment.parse(raw_fragment)
    preview.css(tag_name).first[attribute]
  end

  shared_context "engines" do
    before do
      fixture = defined?(@onebox_fixture) ? @onebox_fixture : described_class.onebox_name
      stub_request(:get, defined?(@uri) ? @uri : @link).to_return(status: 200, body: onebox_response(fixture))
    end

    let(:onebox) { described_class.new(link) }
    let(:html) { onebox.to_html }
    let(:data) { Onebox::Helpers.symbolize_keys(onebox.send(:data)) }
    let(:link) { @link }
  end

  shared_examples_for "an engine" do
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

  shared_examples_for "a layout engine" do
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
end
