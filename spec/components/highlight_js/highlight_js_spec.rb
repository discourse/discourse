require 'spec_helper'
require_dependency 'highlight_js/highlight_js'

describe HighlightJs do
  it 'can list languages' do
    HighlightJs.languages.should include('thrift')
  end

  it 'can generate a packed bundle' do
    bundle = HighlightJs.bundle(["thrift", "http"])
    bundle.should =~ /thrift/
    bundle.should =~ /http/
    bundle.should_not =~ /applescript/
  end


  it 'can get a version string' do
    version1 = HighlightJs.version("http|cpp")
    version2 = HighlightJs.version("rust|cpp|fake")

    version1.should_not == version2
  end
end
