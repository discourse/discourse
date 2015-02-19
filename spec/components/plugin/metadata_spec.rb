require 'spec_helper'
require_dependency 'plugin/metadata'

describe Plugin::Metadata do
  context "parse" do
    it "correctly parses plugin info" do
      metadata = Plugin::Metadata.parse <<TEXT
# name: plugin-name
# about: about: my plugin
# version: 0.1
# authors: Frank Zappa
# url: http://discourse.org

some_ruby
TEXT

      expect(metadata.name).to eq("plugin-name")
      expect(metadata.about).to eq("about: my plugin")
      expect(metadata.version).to eq("0.1")
      expect(metadata.authors).to eq("Frank Zappa")
      expect(metadata.url).to eq("http://discourse.org")
    end
  end

end
