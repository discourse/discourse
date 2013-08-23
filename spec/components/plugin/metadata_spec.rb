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
# gem: some_gem
# gem: some_gem, "1"

some_ruby
TEXT

      metadata.name.should == "plugin-name"
      metadata.about.should == "about: my plugin"
      metadata.version.should == "0.1"
      metadata.authors.should == "Frank Zappa"
      metadata.gems.should == ["some_gem", 'some_gem, "1"']
    end
  end

  context "find_all" do
    it "can find plugins correctly" do
      metadatas = Plugin::Metadata.find_all("#{Rails.root}/spec/fixtures/plugins")
      metadatas.count.should == 1
      metadata = metadata[0]

      metadata.name.should == "plugin-name"
      metadata.path.should == "#{Rails.root}/spec/fixtures/plugins/my_plugin/plugin.rb"
    end

    it "does not blow up on missing directory" do
      metadatas = Plugin.find_all("#{Rails.root}/frank_zappa")
      metadatas.count.should == 0
    end
  end
end
