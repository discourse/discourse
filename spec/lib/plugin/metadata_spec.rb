# frozen_string_literal: true

RSpec.describe Plugin::Metadata do
  describe "parse" do
    it "correctly parses plugin info" do
      metadata = Plugin::Metadata.parse <<TEXT
# name: plugin-name
# about: about: my plugin
# version: 0.1
# authors: Frank Zappa
# contact emails: frankz@example.com
# url: http://discourse.org
# required version: 1.3.0beta6+48
# meta_topic_id: 1234
# label: experimental

some_ruby
TEXT

      expect(metadata.name).to eq("plugin-name")
      expect(metadata.about).to eq("about: my plugin")
      expect(metadata.version).to eq("0.1")
      expect(metadata.authors).to eq("Frank Zappa")
      expect(metadata.contact_emails).to eq("frankz@example.com")
      expect(metadata.url).to eq("http://discourse.org")
      expect(metadata.required_version).to eq("1.3.0beta6+48")
      expect(metadata.meta_topic_id).to eq(1234)
      expect(metadata.label).to eq("experimental")
    end
  end

  def official(name)
    metadata = Plugin::Metadata.parse <<TEXT
# name: #{name}
TEXT

    expect(metadata.official?).to eq(true)
  end

  def unofficial(name)
    metadata = Plugin::Metadata.parse <<TEXT
# name: #{name}
TEXT

    expect(metadata.official?).to eq(false)
  end

  it "correctly detects official vs unofficial plugins" do
    official("discourse-adplugin")
    official("discourse-akismet")
    official("discourse-cakeday")
    official("discourse-data-explorer")
    unofficial("babble")
  end

  it "does not support anything but integer for meta_topic_id" do
    metadata = Plugin::Metadata.parse <<TEXT
# meta_topic_id: 1234
TEXT

    expect(metadata.meta_topic_id).to eq(1234)

    metadata = Plugin::Metadata.parse <<TEXT
# meta_topic_id: t/1234 blah
TEXT

    expect(metadata.meta_topic_id).to eq(nil)
  end

  it "truncates long field lengths" do
    metadata = Plugin::Metadata.parse <<TEXT
# name: #{"a" * 100}
# about: #{"a" * 400}
# authors: #{"a" * 300}
# contact_emails: #{"a" * 300}
# url: #{"a" * 600}
# label: #{"a" * 100}
# required_version: #{"a" * 1500}
TEXT

    expect(metadata.name.length).to eq(Plugin::Metadata::MAX_FIELD_LENGTHS[:name])
    expect(metadata.about.length).to eq(Plugin::Metadata::MAX_FIELD_LENGTHS[:about])
    expect(metadata.authors.length).to eq(Plugin::Metadata::MAX_FIELD_LENGTHS[:authors])
    expect(metadata.contact_emails.length).to eq(
      Plugin::Metadata::MAX_FIELD_LENGTHS[:contact_emails],
    )
    expect(metadata.url.length).to eq(Plugin::Metadata::MAX_FIELD_LENGTHS[:url])
    expect(metadata.label.length).to eq(Plugin::Metadata::MAX_FIELD_LENGTHS[:label])
    expect(metadata.required_version.length).to eq(1000)
  end
end
