# frozen_string_literal: true

# We strip posts before detecting mentions, oneboxes, attachments etc.
# We strip those elements that shouldn't be detected. For example,
# a mention inside a quote should be ignored, so we strip it off.
class PostStripper
  QUOTE_TAG = "aside"
  QUOTE_CLASS = "quote"

  def self.strip(nokogiri_fragment)
    run_core_strippers(nokogiri_fragment)
    run_plugin_strippers(nokogiri_fragment)
    nokogiri_fragment
  end

  private

  # Descendant selectors such as `aside.quote .mention` rescan the subtree of
  # every quote, so deeply nested quotes cost quadratically. Walk once instead,
  # tracking whether a node sits below a quote or a pre and whether its
  # immediate parent is a quote, without re-reading ancestor classes.
  def self.run_core_strippers(fragment)
    removals = []
    stack = fragment.element_children.map { |child| [child, false, false, false] }

    until stack.empty?
      node, in_quote, in_pre, immediate_parent_is_quote = stack.pop
      classes = node["class"].to_s.split

      if strip_node?(classes, in_quote:, in_pre:, immediate_parent_is_quote:)
        removals << node
        next
      end

      is_quote = quote?(node, classes)
      below_quote = in_quote || is_quote
      below_pre = in_pre || node.name == "pre"
      node.element_children.each { |child| stack << [child, below_quote, below_pre, is_quote] }
    end

    removals.each(&:remove)
  end

  def self.strip_node?(classes, in_quote:, in_pre:, immediate_parent_is_quote:)
    return true if classes.include?("onebox") || classes.include?("elided")
    return true if classes.include?("mention") && (in_quote || in_pre)
    return true if classes.include?("mention-group") && in_quote
    classes.include?("title") && immediate_parent_is_quote
  end

  def self.quote?(node, classes)
    node.name == QUOTE_TAG && classes.include?(QUOTE_CLASS)
  end

  def self.run_plugin_strippers(nokogiri_fragment)
    DiscoursePluginRegistry.post_strippers.each do |stripper|
      stripper[:block].call(nokogiri_fragment)
    end
  end

  private_class_method :run_core_strippers, :strip_node?, :quote?, :run_plugin_strippers
end
