require "spec_helper"

describe Onebox::Engine::OpenGraph do
  before(:all) do
    @link = "http://flickr.com"
    fake(@link, response("flickr"))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  describe "#raw" do
    class OneboxEngineOpenGraph
<<<<<<< HEAD:spec/lib/onebox/engine/open_graph_spec.rb
<<<<<<< HEAD:spec/lib/onebox/engine/open_graph_spec.rb
=======
      include Onebox::Engine
>>>>>>> We need the behavior of engine, renaming classes for clarity.:spec/lib/onebox/engine/opengraph_spec.rb
=======
<<<<<<< HEAD:spec/lib/onebox/engine/opengraph_spec.rb
      include Onebox::Engine
=======
>>>>>>> we want to use the class template name for responses.:spec/lib/onebox/engine/open_graph_spec.rb
>>>>>>> we want to use the class template name for responses.:spec/lib/onebox/engine/open_graph_spec.rb
      include Onebox::Engine::OpenGraph

      def initialize(link)
        @url = link
      end
    end

    it "returns a OpenGraph object that has a metadata method" do
      object = OneboxEngineOpenGraph.new("http://flickr.com").send(:raw)
      expect(object).to respond_to(:metadata)
    end
  end
end
