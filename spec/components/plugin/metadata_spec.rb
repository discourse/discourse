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

some_ruby
TEXT

      metadata.name.should == "plugin-name"
      metadata.about.should == "about: my plugin"
      metadata.version.should == "0.1"
      metadata.authors.should == "Frank Zappa"
    end
  end

end
