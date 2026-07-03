# frozen_string_literal: true

require "prism"

module Migrations
  module Tooling
    module Coverage
      # Walks a Ruby source string with Prism and collects, per IntermediateDB
      # model, the keyword names passed to every `IntermediateDB::<Model>.create`
      # call site.
      #
      # Converter call sites use the bare `IntermediateDB::<Model>` receiver
      # (resolved lexically through `Conversion::Step`), but the same receiver may
      # also be written with leading qualification (e.g.
      # `Database::IntermediateDB::Upload`). We therefore match on the trailing
      # `IntermediateDB::<Const>` segment regardless of qualification, then resolve
      # `<Const>` against `Migrations::Database::IntermediateDB`.
      #
      # A `.create` call on a constant that doesn't resolve to a model — e.g. the
      # model of a table that was removed from the schema — would raise at
      # runtime, so such call sites are reported as unknown models instead of
      # being silently skipped.
      #
      # A column passed via `**splat` or a non-literal keyword can't be verified
      # statically, so the scanner raises an {AnalysisError} rather than silently
      # under-reporting.
      class CreateCallScanner < Prism::Visitor
        INTERMEDIATE_DB = :IntermediateDB
        private_constant :INTERMEDIATE_DB

        # `columns` are the written columns per model name; `unknown_models` are
        # the call site locations per non-resolving model name.
        Result = Data.define(:columns, :unknown_models)

        # @param source [String] Ruby source to analyse
        # @param path [String] source location, used in error messages and
        #   unknown model call site locations
        # @return [Result]
        def self.scan(source, path:)
          result = Prism.parse(source)

          unless result.success?
            details = result.errors.map { |e| "#{e.message} (line #{e.location.start_line})" }
            raise AnalysisError, "Failed to parse #{path}: #{details.join(", ")}"
          end

          scanner = new(path)
          result.value.accept(scanner)
          Result.new(columns: scanner.columns, unknown_models: scanner.unknown_models)
        end

        attr_reader :columns, :unknown_models

        def initialize(path)
          super()
          @path = path
          @columns = Hash.new { |hash, key| hash[key] = Set.new }
          @unknown_models = Hash.new { |hash, key| hash[key] = [] }
        end

        def visit_call_node(node)
          record_create_call(node)
          super
        end

        private

        def record_create_call(node)
          return unless node.name == :create

          receiver = node.receiver
          return unless receiver.is_a?(Prism::ConstantPathNode)
          return unless const_name(receiver.parent) == INTERMEDIATE_DB

          model_name = receiver.name.to_s

          if model?(model_name)
            collect_keywords(node, model_name)
          else
            @unknown_models[model_name] << "#{@path}:#{node.location.start_line}"
          end
        end

        # Whether the constant resolves to a model that responds to `create`.
        def model?(model_name)
          model = Migrations::Database::IntermediateDB.const_get(model_name, false)
          model.respond_to?(:create)
        rescue NameError
          false
        end

        def const_name(node)
          case node
          when Prism::ConstantReadNode, Prism::ConstantPathNode
            node.name
          end
        end

        def collect_keywords(node, model_name)
          # Ensure the model is recorded even when a call site passes no
          # columns at all.
          @columns[model_name]

          arguments = node.arguments
          return unless arguments

          arguments.arguments.each do |argument|
            next unless argument.is_a?(Prism::KeywordHashNode)

            argument.elements.each { |element| record_keyword(element, model_name, node) }
          end
        end

        def record_keyword(element, model_name, node)
          if element.is_a?(Prism::AssocSplatNode)
            raise AnalysisError, unverifiable_message("a `**` splat", model_name, node)
          end

          # A `KeywordHashNode` only ever holds `AssocNode`/`AssocSplatNode`
          # elements, and the splat is handled above, so `element` is an
          # `AssocNode` here and always responds to `key`.
          key = element.key
          unless key.is_a?(Prism::SymbolNode)
            raise AnalysisError, unverifiable_message("a non-literal keyword", model_name, node)
          end

          @columns[model_name] << key.unescaped.to_sym
        end

        def unverifiable_message(what, model_name, node)
          "Cannot statically analyse `IntermediateDB::#{model_name}.create` at " \
            "#{@path}:#{node.location.start_line}: it passes #{what}. " \
            "Pass each column as an explicit keyword so coverage can be verified."
        end
      end
    end
  end
end
