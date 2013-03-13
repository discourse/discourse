require_dependency 'oneboxer/oembed_onebox'
require_dependency 'freedom_patches/rails4'

module Oneboxer
  class DiscourseRemoteOnebox < HandlebarsOnebox

    matcher /^https?\:\/\/meta\.discourse\.org\/.*$/
    favicon 'discourse.png'

    def template
      template_path('simple_onebox')
    end

    def parse(data)
      doc = Nokogiri::HTML(data)
      open_graph = Oneboxer.parse_open_graph(doc)
      open_graph['text'] = open_graph['description']
      open_graph
    end

  end
end
