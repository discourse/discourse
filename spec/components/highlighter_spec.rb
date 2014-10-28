require 'spec_helper'
require_dependency 'highlighter'

describe Highlighter do

  it "No language" do
    result =  Highlighter.generate([], "public/javascripts/highlight.pack.js")
    result.should include("var hljs=new function(){")
    result.scan(/registerLanguage\("/).size.should eql(0)
  end

  it "Single language" do
    result =  Highlighter.generate(['Apache'], "public/javascripts/highlight.pack.js")
    result.should include("var hljs=new function(){")
    result.should include("registerLanguage(\"apache")
    result.scan(/registerLanguage\("/).size.should eql(1)
  end

  it "Multiple languages" do
    result =  Highlighter.generate(['Apache', 'Bash'], "public/javascripts/highlight.pack.js")
    result.should include("var hljs=new function(){")
    result.should include("registerLanguage(\"apache")
    result.should include("registerLanguage(\"bash")
    result.scan(/registerLanguage\("/).size.should eql(2)
  end

  it "All registered languages" do
    Highlighter.languages().each{|key, value|
      result =  Highlighter.generate([key], "public/javascripts/highlight.pack.js")
      result.should include("var hljs=new function(){")
      result.should include("registerLanguage(\"#{value}")
      result.scan(/registerLanguage\("/).size.should eql(1)
    }
  end
end

