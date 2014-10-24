require 'spec_helper'
require_dependency 'highlighter'

describe Highlighter do

  it "No language" do
    result =  Highlighter.generate([], "public/javascripts/highlight")
    result.should include("window.hljs")
  end

  it "Single language" do
    result =  Highlighter.generate(['Apache'], "public/javascripts/highlight")
    result.should include("window.hljs")
    result.should include("['apacheconf']")
  end

  it "Multiple languages" do
    result =  Highlighter.generate(['Apache', 'Bash'], "public/javascripts/highlight")
    result.should include("window.hljs")
    result.should include("['apacheconf']")
    result.should include("['sh'")
  end
end

