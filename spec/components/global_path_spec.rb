require 'rails_helper'
require 'global_path'

class GlobalPathInstance
  extend GlobalPath
end

describe GlobalPath do

  context 'cdn_relative_path' do
    def cdn_relative_path(p)
      GlobalPathInstance.cdn_relative_path(p)
    end

    it "just returns path for no cdn" do
      expect(cdn_relative_path("/test")).to eq("/test")
    end

    it "returns path when a cdn is defined with a path" do
      GlobalSetting.expects(:cdn_url).returns("//something.com/foo")
      expect(cdn_relative_path("/test")).to eq("/foo/test")
    end

    it "returns path when a cdn is defined with a path" do
      GlobalSetting.expects(:cdn_url).returns("https://something.com:221/foo")
      expect(cdn_relative_path("/test")).to eq("/foo/test")
    end

  end
end
