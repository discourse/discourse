# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Migrations
      # This is advisory: an implicit generator result can be observed through
      # StopIteration#result, so replacing #yield with #<< is not always safe.
      class SingleValueYielder < Base
        MSG = "Prefer `<<` for one yielded value unless the consumer's return value is needed."
        RESTRICT_ON_SEND = [:yield].freeze
        ITERATORS = %i[each each_slice each_with_index times loop].freeze

        def on_send(node)
          return unless node.receiver&.lvar_type? && node.arguments.one?
          argument = node.first_argument
          return if argument.splat_type? || argument.block_pass_type?
          return if argument.hash_type? && !argument.braces?

          name = node.receiver.children.first
          generator = generator_for(node, name)
          return unless generator
          return if generator.each_descendant(:lvasgn).any? { |assignment| assignment.name == name }
          return unless discarded_or_implicit_result?(node, generator)

          add_offense(node.loc.selector)
        end

        private

        def generator_for(node, name)
          node.each_ancestor do |ancestor|
            return nil if ancestor.type?(:def, :defs, :class, :module, :sclass)
            next unless ancestor.block_type?
            unless ancestor.arguments.children.any? { |argument| argument.children.first == name }
              next
            end

            call = ancestor.send_node
            if call.method?(:new) && call.receiver&.const_type? &&
                 call.receiver.const_name == "Enumerator" && ancestor.arguments.children.one? &&
                 ancestor.arguments.children.first.arg_type?
              return ancestor
            end
            return nil
          end
          nil
        end

        def discarded_or_implicit_result?(node, generator)
          return true unless node.value_used?

          parent = node.parent
          case parent.type
          when :begin, :kwbegin
            discarded_or_implicit_result?(parent, generator)
          when :if
            parent.condition != node && discarded_or_implicit_result?(parent, generator)
          when :block
            parent == generator || ITERATORS.include?(parent.send_node.method_name)
          else
            false
          end
        end
      end
    end
  end
end
