# frozen_string_literal: true

require "digest"
require "prism"

module RspecSourceStructure
  def self.describe(path, boot_lines: [])
    source = File.binread(path)
    bodies = method_bodies(source)
    return if bodies.nil?

    immutable_methods =
      bodies.each_index.select do |index|
        body = bodies[index]
        boot_lines.any? { |line| (body.start_line..body.end_line).cover?(line) }
      end
    {
      "digest" => digest(source:, bodies:, immutable_methods:),
      "immutable_methods" => immutable_methods,
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

  def self.method_bodies(source)
    parsed = Prism.parse(source)
    return if parsed.errors.any?

    bodies = []
    pending = [parsed.value]
    until pending.empty?
      node = pending.pop
      if node.is_a?(Prism::DefNode)
        bodies << node.body.location if node.body
      else
        pending.concat(node.compact_child_nodes.reverse)
      end
    end
    bodies
  end
  private_class_method :method_bodies

  def self.digest(source:, bodies:, immutable_methods:)
    edited = source.dup
    bodies.each_with_index.to_a.reverse_each do |body, index|
      next if immutable_methods.include?(index)
      edited[body.start_offset...body.end_offset] = "__method_body__"
    end
    Digest::SHA256.hexdigest(edited)
  end
  private_class_method :digest
end
