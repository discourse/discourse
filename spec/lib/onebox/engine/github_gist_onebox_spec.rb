# Broken for now
#
# require "spec_helper"
# 
# describe Onebox::Engine::GithubGistOnebox do
#   before(:all) do
#     @link = "https://gist.github.com/anikalindtner/153044e9bea3331cc103"
#     @uri = "https://api.github.com/gists/153044e9bea3331cc103"
#   end
# 
#   include_context "engines"
#   it_behaves_like "an engine"
# 
#   describe "#to_html" do
#     it "includes sha" do
#       expect(html).to include("153044e9bea3331cc103")
#     end
# 
#     it "includes script" do
#       expect(html).to include("script")
#     end
#   end
# end
