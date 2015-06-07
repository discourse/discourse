module Email
  # HtmlCleaner cleans up the extremely dirty HTML that many email clients
  # generate by stripping out any excess divs or spans, removing styling in
  # the process (which also makes the html more suitable to be parsed as
  # Markdown).
  class HtmlCleaner
    # Elements to hoist all children out of
    HTML_HOIST_ELEMENTS = %w(div span font table tbody th tr td)
    # Node types to always delete
    HTML_DELETE_ELEMENT_TYPES = [
      Nokogiri::XML::Node::DTD_NODE,
      Nokogiri::XML::Node::COMMENT_NODE,
    ]

    # Private variables:
    #   @doc - nokogiri document
    #   @out - same as @doc, but only if trimming has occured
    def initialize(html)
      if String === html
        @doc = Nokogiri::HTML(html)
      else
        @doc = html
      end
    end

    class << self
      # Email::HtmlCleaner.trim(inp, opts={})
      #
      # Arguments:
      #   inp - Either a HTML string or a Nokogiri document.
      # Options:
      #   :return => :doc, :string
      #     Specify the desired return type.
      #     Defaults to the type of the input.
      #     A value of :string is equivalent to calling get_document_text()
      #     on the returned document.
      def trim(inp, opts={})
        cleaner = HtmlCleaner.new(inp)

        opts[:return] ||= ((String === inp) ? :string : :doc)

        if opts[:return] == :string
          cleaner.output_html
        else
          cleaner.output_document
        end
      end

      # Email::HtmlCleaner.get_document_text(doc)
      #
      # Get the body portion of the document, including html, as a string.
      def get_document_text(doc)
        body = doc.xpath('//body')
        if body
          body.inner_html
        else
          doc.inner_html
        end
      end
    end

    def output_document
      @out ||= begin
                 doc = @doc
                 trim_process_node doc
                 add_newlines doc
                 doc
      end
    end

    def output_html
      HtmlCleaner.get_document_text(output_document)
    end

    private

    def add_newlines(doc)
      # Replace <br> tags with a markdown \n
      doc.xpath('//br').each do |br|
        br.replace(new_linebreak_node doc, 2)
      end
      # Surround <p> tags with newlines, to help with line-wise postprocessing
      # and ensure markdown paragraphs
      doc.xpath('//p').each do |p|
        p.before(new_linebreak_node doc)
        p.after(new_linebreak_node doc, 2)
      end
    end

    def new_linebreak_node(doc, count=1)
      Nokogiri::XML::Text.new("\n" * count, doc)
    end

    def trim_process_node(node)
      if should_hoist?(node)
        hoisted = trim_hoist_element node
        hoisted.each { |child| trim_process_node child }
      elsif should_delete?(node)
        node.remove
      else
        if children = node.children
          children.each { |child| trim_process_node child }
        end
      end

      node
    end

    def trim_hoist_element(element)
      hoisted = []
      element.children.each do |child|
        element.before(child)
        hoisted << child
      end
      element.remove
      hoisted
    end

    def should_hoist?(node)
      return false unless node.element?
      HTML_HOIST_ELEMENTS.include? node.name
    end

    def should_delete?(node)
      return true if HTML_DELETE_ELEMENT_TYPES.include? node.type
      return true if node.element? && node.name == 'head'
      return true if node.text? && node.text.strip.blank?

      false
    end
  end
end
