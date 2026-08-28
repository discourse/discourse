# frozen_string_literal: true

module Checklist
  class CheckboxLocator
    Location = Data.define(:count, :checkbox, :needs_recook)
    Target = Data.define(:index, :source)
    SOURCE_PATTERN = /\A(\d+):(\d+)\z/

    def self.call(post:, index:, source: nil)
      call_many(post:, targets: [Target.new(index:, source:)]).first
    end

    def self.call_many(post:, targets:)
      new(post).call_many(targets)
    end

    def initialize(post)
      @post = post
    end

    def call_many(targets)
      locations = build(@post.cooked, targets)
      return locations if locations.none?(&:needs_recook)

      build(@post.cook(@post.raw), targets)
    end

    private

    def build(cooked, targets)
      nodes = Nokogiri::HTML5.fragment(cooked).css("span.chcklst-box")
      if !source_hints_valid?(nodes)
        return targets.map { Location.new(count: nodes.size, checkbox: nil, needs_recook: true) }
      end

      targets.map { |target| build_location(nodes, target) }
    end

    def build_location(nodes, target)
      node =
        if target.source.present?
          nodes.find { |candidate| candidate["data-chk-src"] == target.source }
        else
          nodes[target.index]
        end
      return Location.new(count: nodes.size, checkbox: nil, needs_recook: false) if node.nil?
      if node.classes.include?("permanent")
        return Location.new(count: nodes.size, checkbox: Checkbox.permanent, needs_recook: false)
      end

      checkbox = checkbox_for(node)
      Location.new(count: nodes.size, checkbox:, needs_recook: checkbox.nil?)
    end

    def source_hints_valid?(nodes)
      sources = Set.new

      nodes.each do |node|
        next if node.classes.include?("permanent")

        source = SOURCE_PATTERN.match(node["data-chk-src"].to_s)
        return false if source.nil? || !sources.add?(source[0])
      end

      true
    end

    def checkbox_for(node)
      source = SOURCE_PATTERN.match(node["data-chk-src"].to_s)
      return if source.nil?

      checkbox = source_map.checkbox_at(line: source[1].to_i, nth: source[2].to_i)
      return if checkbox.nil?
      return if checkbox.checked? != node.classes.include?("checked")

      checkbox
    end

    def source_map
      @source_map ||= SourceMap.new(@post.raw)
    end
  end
end
