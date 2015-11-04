require 'psych'
require 'set'

class LocaleFileWalker
  protected

  def handle_document(document)
    # we want to ignore the language (first key), so let's start at -1
    handle_nodes(document.root.children, -1, [])
  end

  def handle_nodes(nodes, depth, parents)
    if nodes
      consecutive_scalars = 0
      nodes.each do |node|
        consecutive_scalars = handle_node(node, depth, parents, consecutive_scalars)
      end
    end
  end

  def handle_node(node, depth, parents, consecutive_scalars)
    node_is_scalar = node.is_a?(Psych::Nodes::Scalar)

    if node_is_scalar
      handle_scalar(node, depth, parents) if valid_scalar?(depth, consecutive_scalars)
    elsif node.is_a?(Psych::Nodes::Alias)
      handle_alias(node, depth, parents)
    elsif node.is_a?(Psych::Nodes::Mapping)
      handle_mapping(node, depth, parents)
      handle_nodes(node.children, depth + 1, parents.dup)
    end

    node_is_scalar ? consecutive_scalars + 1 : 0
  end

  def valid_scalar?(depth, consecutive_scalars)
    depth >= 0 && consecutive_scalars.even?
  end

  def handle_scalar(node, depth, parents)
    parents[depth] = node.value
  end

  def handle_alias(node, depth, parents)
  end

  def handle_mapping(node, depth, parents)
  end
end
