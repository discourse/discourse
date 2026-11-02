# frozen_string_literal: true

require "digest"
require "json"
require "prism"

module RspecSourceStructure
  def self.describe(path, boot_lines: [])
    source = File.binread(path)
    bodies = method_bodies(source)
    return if bodies.nil?

    immutable_methods =
      bodies.each_index.select do |index|
        body = bodies[index]
        boot_lines.any? { |line| (body.location.start_line..body.location.end_line).cover?(line) }
      end
    {
      "digest" => digest(source:, bodies:, immutable_methods:),
      "immutable_methods" => immutable_methods,
      "method_digests" =>
        method_nodes(source).map do |node|
          Digest::SHA256.hexdigest(node.body&.location&.slice.to_s)
        end,
    }
  end

  def self.matches?(path:, description:)
    unless description.is_a?(Hash) && description["digest"].is_a?(String) &&
             description["digest"].match?(/\A[a-f0-9]{64}\z/) &&
             description["immutable_methods"].is_a?(Array) &&
             description["immutable_methods"].all? { |index| index.is_a?(Integer) && index >= 0 }
      return false
    end

    source = File.binread(path)
    bodies = method_bodies(source)
    return false unless bodies

    digest(source:, bodies:, immutable_methods: description["immutable_methods"]) ==
      description["digest"]
  rescue Errno::ENOENT
    false
  end

  def self.method_nodes(source)
    parsed = Prism.parse(source)
    return if parsed.errors.any?

    definitions(parsed.value)
  end
  private_class_method :method_nodes

  def self.definitions(root)
    bodies = []
    pending = [root]
    until pending.empty?
      node = pending.pop
      if node.is_a?(Prism::DefNode)
        bodies << node
      else
        pending.concat(node.compact_child_nodes.reverse)
      end
    end
    bodies
  end

  def self.method_bodies(source)
    method_nodes(source)&.filter_map(&:body)
  end
  private_class_method :method_bodies

  def self.changed_methods(path:, description:)
    previous = description["method_digests"]
    current = method_nodes(File.binread(path))
    unless previous.is_a?(Array) && current && previous.length == current.length
      raise "Method correspondence changed"
    end
    current.each_index.filter_map do |index|
      if previous[index] != Digest::SHA256.hexdigest(current[index].body&.location&.slice.to_s)
        "__method__/#{path}/#{index}"
      end
    end
  end

  def self.digest(source:, bodies:, immutable_methods:)
    edited = source.dup
    bodies.each_with_index.to_a.reverse_each do |body, index|
      next if immutable_methods.include?(index)
      edited[body.location.start_offset...body.location.end_offset] = JSON.generate(
        dependency_effects(body),
      ).b
    end
    Digest::SHA256.hexdigest(edited)
  end
  private_class_method :digest

  def self.dependency_effects(body)
    effects = []
    pending = [body]
    until pending.empty?
      node = pending.pop
      type = node.class.name
      return [["nested definition", body.location.slice]] if node.is_a?(Prism::DefNode)
      if node.is_a?(Prism::CallNode)
        if %i[
             send
             __send__
             public_send
             eval
             instance_eval
             class_eval
             module_eval
             instance_exec
             class_exec
             module_exec
             define_method
             define_singleton_method
           ].include?(node.name)
          return [["dynamic", body.location.slice]]
        end
        effects << [
          type,
          node.name.to_s,
          node.receiver&.location&.slice,
          node.arguments&.location&.slice,
        ]
      elsif type.match?(
            /(?:If|Unless|Case|When|While|Until|For|Rescue|Ensure|And|Or|Return|Break|Next|Redo|Retry|FlipFlop|MatchPredicate|MatchRequired|LocalVariable.*(?:Write|Target))Node\z/,
          )
        effects << [type, node.location.slice]
      elsif type.match?(
            /(?:Integer|Float|Rational|Imaginary|String|Symbol|RegularExpression|Array|Hash|True|False|Nil)Node\z/,
          )
        effects << [type]
      elsif type.match?(/(?:Variable|Constant|Def|Class|Module|Yield|Super|Alias|Undef)/)
        effects << [type, node.respond_to?(:name) ? node.name.to_s : node.location.slice]
      end
      pending.concat(node.compact_child_nodes.reverse)
    end
    effects
  end
  private_class_method :dependency_effects
end
