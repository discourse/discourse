# frozen_string_literal: true
require "prism"
require_relative "rspec_source_structure"
require_relative "dependency_set"
require_relative "dependency_graph"

module TestSelection
  class RubyDependencies
    OBJECT_IDENTITY = BasicObject.instance_method(:equal?)
    private_constant :OBJECT_IDENTITY

    def initialize(root:)
      @roots = [File.expand_path(root), File.realpath(root)].uniq.map { |path| "#{path}/" }
      @dependency_sets = DependencySet::Registry.new
      @empty_sources = @dependency_sets.build.freeze
      @sources = Hash.new { |hash, source| hash[source] = @dependency_sets.build }
      @tests = Hash.new { |hash, test| hash[test] = @dependency_sets.build }
      @frames = Hash.new { |hash, thread| hash[thread] = [] }
      @scopes = Hash.new { |hash, thread| hash[thread] = [] }
      @coarse_depth = Hash.new(0)
      @definitions = {}.compare_by_identity
      @mutations = {}
      @initializing = Hash.new(0)
      @loading = Hash.new(0)
      @loading_calls = {}
      @initialization_sources = @dependency_sets.build
      @uncertain_sources = @dependency_sets.build
      @observed_sources = Set.new
      @initialization_lines = Hash.new { |hash, path| hash[path] = Set.new }
      @objects = ObjectSpace::WeakMap.new
      @receiver_namespaces = ObjectSpace::WeakMap.new
      @constants = ObjectSpace::WeakMap.new
      @external_owners = ObjectSpace::WeakMap.new
      @external_write_depth = 0
      @external_entry_lines = {}
      @external_line_trace = TracePoint.new(:line) { |event| record_external_write(event) }
      @source_sets = {}
      @effects = {}
      @effect_locations = {}
      @source_paths = {}
      @test_paths = {}
      @active_test = nil
      @test_thread = nil
      @trace =
        TracePoint.new(
          :call,
          :c_call,
          :b_call,
          :return,
          :c_return,
          :b_return,
          :class,
          :end,
        ) do |event|
          if event.event == :class
            @initializing[Thread.current] += 1 if source_path(event.path)
          elsif event.event == :end
            if source_path(event.path)
              record_constants(event.self)
              @initializing[Thread.current] -= 1
            end
          else
            loading =
              %i[require require_relative].include?(event.method_id) ||
                (
                  event.method_id == :load_iseq &&
                    OBJECT_IDENTITY.bind_call(event.self, RubyVM::InstructionSequence)
                )
            @loading[Thread.current] += 1 if loading && %i[call c_call].include?(event.event)
            dynamic = %i[
              class_eval
              module_eval
              class_exec
              module_exec
              eval
              define_method
              define_singleton_method
            ].include?(event.method_id)
            @initializing[Thread.current] += 1 if dynamic && event.event == :c_call
            record(event: event, dynamic: dynamic)
            @initializing[Thread.current] -= 1 if dynamic && event.event == :c_return
            @loading[Thread.current] -= 1 if loading && %i[return c_return].include?(event.event) &&
              @loading[Thread.current].positive?
          end
        end
    end

    def start
      @trace.enable
    end

    def stop
      @trace.disable
      @external_line_trace.disable
    end

    def begin_test(path)
      raise "Overlapping test collection" if @active_test
      @active_test = path
      @test_thread = Thread.current
      @tests[path]
    end

    def finish_test
      @active_test = nil
      @test_thread = nil
    end

    def snapshot(compact: false)
      result = {
        "observed_sources" => @observed_sources.to_a.sort,
        "initialization_sources" => @initialization_sources.to_a.sort,
        "uncertain_sources" => @uncertain_sources.to_a.sort,
        "initialization_lines" =>
          @initialization_lines.transform_values { |lines| lines.to_a.sort },
      }
      if compact
        graph = DependencyGraph.new
        @sources.each do |source, dependencies|
          graph.record(source: source, dependencies: dependencies)
        end
        @tests.each do |file, dependencies|
          graph.record_test(file: file, dependencies: dependencies)
        end
        result.merge("dependency_graph" => graph.to_h, "tests" => graph.encoded_tests)
      else
        result.merge(
          "tests" => @tests.transform_values { |paths| paths.to_a.sort },
          "source_dependencies" => @sources.transform_values { |paths| paths.to_a.sort },
        )
      end
    end

    private

    def relative_path(path)
      return unless path
      root = @roots.find { |candidate| path.start_with?(candidate) }
      path.delete_prefix(root) if root
    end

    def source_path(path)
      @source_paths.fetch(path) { @source_paths[path] = uncached_source_path(path) }
    end

    def uncached_source_path(path)
      relative = relative_path(path)
      if relative&.end_with?(".rb") && test_path(path) && !relative.end_with?("_spec.rb")
        return relative
      end
      return relative if relative&.match?(%r{\Aplugins/[^/]+/plugin\.rb\z})
      if relative&.match?(
           %r{\A(?:app/|lib/|config/|plugins/[^/]+/(?:app|lib)/|migrations/[^/]+/lib/).*\.rb\z},
         )
        relative
      end
    end

    def test_path(path)
      @test_paths.fetch(path) do
        relative = relative_path(path)
        @test_paths[path] = (
          if relative&.match?(
               %r{\A(?:spec/|plugins/[^/]+/spec/|migrations/[^/]+/spec/|(?:tmp/)?themes/[^/]+/spec/)},
             )
            relative
          else
            nil
          end
        )
      end
    end

    def weak_object?(value)
      if Object.instance_method(:frozen?).bind_call(value)
        return false if String === value
        return false if Array === value && Array.instance_method(:empty?).bind_call(value)
        return false if Hash === value && Hash.instance_method(:empty?).bind_call(value)
        return false if Set === value && Set.instance_method(:empty?).bind_call(value)
      end
      [Hash, Array, Set, String].any? { |type| type === value }
    end

    def state_sources?(sources)
      if DependencySet === sources
        sources.state_sources?
      else
        sources.any? { |path| path.start_with?("__state__/") }
      end
    end

    def object_sources(value)
      @objects[value] || @empty_sources
    end

    def cache_value?(value)
      if [NilClass, TrueClass, FalseClass, Numeric, Symbol, Module].any? { |type| type === value }
        return false
      end
      return weak_object?(value) if [Hash, Array, Set, String].any? { |type| type === value }
      true
    end

    def record_object(value:, sources:, field: false)
      return unless field ? cache_value?(value) : weak_object?(value)
      combined = @dependency_sets.build(object_sources(value)).merge(sources).freeze
      @objects[value] = @source_sets[combined.bits] ||= combined
    end

    def record_constants(owner)
      Module
        .instance_method(:constants)
        .bind_call(owner, false)
        .each do |name|
          next if Module.instance_method(:autoload?).bind_call(owner, name, false)
          definition = Module.instance_method(:const_source_location).bind_call(owner, name, false)
          source = source_path(definition&.first)
          next unless source
          value = Module.instance_method(:const_get).bind_call(owner, name, false)
          next unless cache_value?(value)
          namespace = Module.instance_method(:name).bind_call(owner) || "anonymous"
          recorded =
            record_object(
              value: value,
              sources: [source, "__state__/constant/#{namespace}/#{name}"],
              field: true,
            )
          @constants[value] = recorded
        end
    end

    def effects(path:, line:, block:, method_name:)
      locations = @effect_locations[path] ||= {}
      identity = [line, block, method_name]
      return locations.fetch(identity) if locations.key?(identity)
      definitions =
        @effects.fetch(path) do
          pending = [Prism.parse_file(path).value]
          methods = RspecSourceStructure.definitions(pending.first)
          found = []
          boundaries = {}.compare_by_identity
          until pending.empty?
            node = pending.pop
            if node.is_a?(Prism::CallNode) && node.block.is_a?(Prism::BlockNode)
              boundaries[node.block] = %i[
                it
                specify
                example
                scenario
                fit
                fexample
                fspecify
                xit
                xexample
                xspecify
                before
                after
                around
                prepend_before
                append_before
                prepend_after
                append_after
              ].include?(node.name)
            end
            if node.is_a?(Prism::DefNode) || node.is_a?(Prism::BlockNode)
              reads = Set.new
              writes = Set.new
              write_lines = Hash.new { |hash, variable| hash[variable] = [] }
              unknown = false
              body = [node.body].compact
              until body.empty?
                child = body.pop
                type = child.class.name
                if child.is_a?(Prism::CallNode) && (source_path(path) || test_path(path))
                  dispatch = %i[
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
                    const_get
                    method
                    public_method
                    instance_method
                    public_instance_method
                  ].include?(child.name)
                  lookup =
                    %i[[] fetch dig fetch_values values_at].include?(child.name) &&
                      child.arguments&.arguments&.any? do |argument|
                        ![
                          Prism::SymbolNode,
                          Prism::StringNode,
                          Prism::IntegerNode,
                          Prism::FloatNode,
                          Prism::TrueNode,
                          Prism::FalseNode,
                          Prism::NilNode,
                        ].any? { |literal| argument.is_a?(literal) }
                      end
                  unknown = true if dispatch || lookup ||
                    (source_path(path) && child.block.is_a?(Prism::BlockNode))
                end
                if type.include?("InstanceVariable")
                  if type.end_with?("ReadNode") || type.match?(/(?:And|Or|Operator)WriteNode\z/)
                    reads.add(child.name)
                  end
                  if type.end_with?("WriteNode", "TargetNode")
                    writes.add(child.name)
                    write_lines[child.name] << (child.location.start_line..child.location.end_line)
                  end
                elsif type.match?(/(?:Class|Global)Variable.*(?:Write|Target)Node\z/) ||
                      (
                        type.match?(
                          /(?:If|Unless|Case|When|While|Until|For|Rescue|Ensure|And|Or|Return|Break|Next|Redo|Retry|FlipFlop|MatchPredicate|MatchRequired)Node\z/,
                        ) &&
                          !(
                            child.respond_to?(:predicate) &&
                              [Prism::TrueNode, Prism::FalseNode, Prism::NilNode].any? do |literal|
                                child.predicate.is_a?(literal)
                              end
                          )
                      )
                  unknown = true
                end
                body.concat(child.compact_child_nodes) unless child.is_a?(Prism::DefNode)
              end
              owner_index =
                methods.each_index.find do |index|
                  definition = methods[index]
                  node.location.start_offset >= definition.location.start_offset &&
                    node.location.end_offset <= definition.location.end_offset
                end
              found << {
                method_index: owner_index,
                test_boundary: boundaries.fetch(node, false),
                body_line: node.body&.location&.start_line || node.location.start_line,
                range: node.location.start_line..node.location.end_line,
                block: node.is_a?(Prism::BlockNode),
                method_name: node.is_a?(Prism::DefNode) ? node.name : nil,
                write_lines: write_lines,
                reads: reads.to_a,
                writes: writes.to_a,
                unknown: unknown,
              }
            end
            pending.concat(node.compact_child_nodes)
          end
          @effects[path] = found
        end
      candidates =
        definitions.select do |definition|
          definition.fetch(:range).cover?(line) && definition.fetch(:block) == block
        end
      candidates.select! { |definition| definition.fetch(:method_name) == method_name } unless block
      if candidates.empty? && !block
        candidates =
          definitions.select do |definition|
            definition.fetch(:range).cover?(line) && definition.fetch(:block)
          end
      end
      smallest = candidates.map { |definition| definition.fetch(:range).size }.min
      closest = candidates.select { |definition| definition.fetch(:range).size == smallest }
      locations[identity] = if closest.one?
        closest.first
      elsif closest.any? && test_path(path)
        {
          reads: closest.flat_map { |definition| definition.fetch(:reads) }.uniq,
          writes: closest.flat_map { |definition| definition.fetch(:writes) }.uniq,
          unknown: closest.any? { |definition| definition.fetch(:unknown) },
          test_boundary: closest.any? { |definition| definition.fetch(:test_boundary) },
          uncertain_scope: true,
        }
      else
        { reads: [], writes: [], unknown: true }
      end
    end

    def active_example
      unless @active_test && defined?(RSpec) && RSpec.respond_to?(:current_scope) &&
               RSpec.current_scope == :example
        return
      end
      example = RSpec.current_example
      return unless example
      metadata = example.example_group.metadata
      metadata = metadata.fetch(:parent_example_group) while metadata[:parent_example_group]
      owner = relative_path(File.expand_path(metadata.fetch(:rerun_file_path)))
      example if owner == @active_test
    end

    def external_entry_line(event)
      return if event.event == :b_call || !event.defined_class || !event.callee_id
      method = event.defined_class.instance_method(event.callee_id)
      @external_entry_lines.fetch(method) do
        @external_entry_lines[method] = RubyVM::InstructionSequence
          .of(method)
          &.trace_points
          &.find { |line, kind| kind == :line }
          &.first
      end
    end

    def record_external_write(event)
      @scopes[Thread.current].each do |frame|
        unless frame[:external_write_path] == event.path &&
                 OBJECT_IDENTITY.bind_call(frame.fetch(:receiver), event.self)
          next
        end
        frame
          .fetch(:external_write_lines)
          .each do |variable, ranges|
            if ranges.any? { |range| range.cover?(event.lineno) }
              frame.fetch(:executed_writes).add(variable)
            end
          end
      end
    end

    def state_namespace(receiver)
      if @active_test && defined?(RSpec::Core::ExampleGroup) &&
           RSpec::Core::ExampleGroup === receiver
        return "__state__/spec/#{@active_test}"
      end
      @receiver_namespaces[receiver] ||= begin
        singleton = Module === receiver
        owner = singleton ? receiver : Object.instance_method(:class).bind_call(receiver)
        name = Module.instance_method(:name).bind_call(owner) || "anonymous"
        namespace = "__state__/#{singleton ? "class" : "instance"}/#{name}".freeze
        @sources[namespace]
        namespace
      end
    end

    def record_state_slot(receiver:, variable:)
      namespace = state_namespace(receiver)
      slot = "#{namespace}/#{variable}"
      @sources[namespace].add(slot)
      slot
    end

    def explicit_loading?(path:, line:)
      lines =
        @loading_calls.fetch(path) do
          pending = [Prism.parse_file(path).value]
          found = Set.new
          until pending.empty?
            node = pending.pop
            if node.is_a?(Prism::CallNode) &&
                 %i[require require_relative load send public_send __send__].include?(node.name)
              found.merge(node.location.start_line..node.location.end_line)
            end
            pending.concat(node.compact_child_nodes)
          end
          @loading_calls[path] = found
        end
      lines.include?(line)
    end

    def tracked_hash_read?(event:, inputs:)
      unless event.method_id == :[] && event.defined_class == Hash &&
               Object.instance_method(:class).bind_call(event.self) == Hash &&
               state_sources?(inputs) &&
               Hash.instance_method(:default_proc).bind_call(event.self).nil?
        return false
      end
      default = Object.instance_method(:method).bind_call(event.self, :default)
      return false unless default.owner == Hash && default.source_location.nil?
      return false unless File.file?(event.path)
      @hash_lookup_lines ||= {}
      lines =
        @hash_lookup_lines.fetch(event.path) do
          by_line = Hash.new { |hash, line| hash[line] = [] }
          parsed = Prism.parse_file(event.path)
          return false if parsed.errors.any?
          pending = [parsed.value]
          until pending.empty?
            node = pending.pop
            if node.is_a?(Prism::CallNode) && node.name == :[]
              arguments = node.arguments&.arguments
              literal = arguments&.one? && arguments.first.is_a?(Prism::SymbolNode)
              (node.location.start_line..node.location.end_line).each do |line|
                by_line[line] << literal
              end
            end
            pending.concat(node.compact_child_nodes)
          end
          @hash_lookup_lines[event.path] = by_line.transform_values { |lookups| lookups.all? }
        end
      lines.fetch(event.lineno, false)
    end

    def mutation?(event)
      [event.method_id, event.callee_id].compact.any? do |name|
        @mutations.fetch(name) do
          value = name.to_s
          @mutations[name] = value.match?(/\A[a-zA-Z_]\w*=\z/) ||
            %w[
              write
              syswrite
              pwrite
              write_nonblock
              puts
              print
              printf
              truncate
              rename
              unlink
              []=
              <<
              push
              append
              prepend
              pop
              shift
              unshift
              insert
              fill
              setbyte
              bytesplice
              force_encoding
              rehash
              compare_by_identity
              reset
              delete
              delete?
              delete_at
              delete_if
              keep_if
              clear
              replace
              concat
              merge
              merge!
              update
              store
              add
              add?
              subtract
            ].include?(value) || value.end_with?("!")
        end
      end
    end

    def finish_frame(event:, frame:)
      return unless frame
      frame[:unknown] = true if frame[:native_dispatch] && !frame[:callback_seen]
      record_constants(frame.fetch(:constant_owner)) if frame[:constant_owner]
      inputs = frame.fetch(:inputs).dup
      if frame[:parent] &&
           (
             frame.fetch(:argument_write) ||
               (frame.fetch(:unknown) && !frame.fetch(:opaque_without_arguments))
           )
        inputs.merge(frame.fetch(:parent).fetch(:inputs))
      end
      if frame.fetch(:argument_write) || frame.fetch(:unknown)
        inputs.merge(frame.fetch(:argument_inputs))
      end
      variables = frame.fetch(:variables)
      if frame[:executed_writes]
        variables &= frame.fetch(:executed_writes).to_a
        written =
          variables.map do |variable|
            record_state_slot(receiver: frame.fetch(:receiver), variable: variable)
          end
      else
        written = frame.fetch(:writes).uniq
      end
      written.each { |slot| @sources[slot].merge(inputs - [slot]) }
      if frame.fetch(:native) && !written.empty?
        record_object(value: frame.fetch(:receiver), sources: written, field: true)
      end
      if frame.fetch(:unknown) && frame.fetch(:opaque_without_arguments)
        @initialization_sources.merge(inputs)
        @uncertain_sources.merge(inputs)
      elsif frame.fetch(:unknown)
        owner = frame
        owner = owner[:parent] while owner && !(owner[:source] && owner[:body_line])
        if owner
          owner[:unknown] = true
          source = owner.fetch(:source)
          method = owner.fetch(:method_node)
          @sources[method].merge(inputs - [method])
          @initialization_sources.add(method)
          @initialization_lines[source].add(owner.fetch(:body_line))
        elsif frame[:source]
          @sources[frame.fetch(:source)].merge(inputs - [frame.fetch(:source)])
          @initialization_sources.add(frame.fetch(:source))
          @uncertain_sources.add(frame.fetch(:source))
        else
          @initialization_sources.merge(inputs)
          @uncertain_sources.merge(inputs)
        end
      end
      variables.each do |variable|
        value =
          Object.instance_method(:instance_variable_get).bind_call(frame.fetch(:receiver), variable)
        slot = record_state_slot(receiver: frame.fetch(:receiver), variable: variable)
        record_object(value: value, sources: [frame.fetch(:method_node), slot].compact, field: true)
      end
      value = event.return_value
      recorded = record_object(value: value, sources: frame.fetch(:inputs)) if (
        frame[:source] || frame.fetch(:native)
      ) && object_sources(value).empty?
      @constants[value] = recorded if recorded && cache_value?(event.self) && @constants[event.self]
    end

    def method_definition(event)
      return event.path, event.lineno unless event.event == :c_call
      methods = @definitions[event.defined_class] ||= {}
      methods.fetch(event.callee_id) do
        methods[event.callee_id] = begin
          event.defined_class.instance_method(event.callee_id).source_location
        rescue NameError
          nil
        end
      end
    end

    def record(event:, dynamic:)
      frames = @frames[Thread.current]
      returning = %i[return c_return b_return].include?(event.event)
      if !returning &&
           %i[
             method_added
             singleton_method_added
             method_removed
             singleton_method_removed
             method_undefined
             singleton_method_undefined
           ].include?(event.method_id)
        @definitions.clear
      end
      depth = @coarse_depth[Thread.current]
      if depth.positive?
        if returning
          @coarse_depth[Thread.current] -= 1
          if depth > 1
            frames.pop
            return
          end
        else
          @coarse_depth[Thread.current] += 1
          frames << nil
          sources = object_sources(event.self)
          namespace = state_namespace(event.self)
          if sources.empty?
            @initialization_sources.add(namespace)
            @tests[@active_test].add(namespace) if @active_test
          else
            dependencies = sources | [namespace]
            @initialization_sources.merge(dependencies)
            @tests[@active_test].merge(dependencies) if @active_test
          end
          if (source = source_path(method_definition(event)&.first))
            @observed_sources.add(source)
            @initialization_sources.add(source)
            @uncertain_sources.add(source)
            @tests[@active_test].add(source) if @active_test
          end
          return
        end
      end
      if returning
        frame = frames.pop
        @scopes[Thread.current].pop if frame
        finish_frame(event: event, frame: frame)
        if frame && frame[:executed_writes]
          @external_write_depth -= 1
          @external_line_trace.disable if @external_write_depth.zero?
        end
        return
      end
      if event.event == :b_call
        dispatch = @scopes[Thread.current].last
        if dispatch && dispatch[:native_dispatch] && !dispatch[:callback_seen]
          dispatch[:callback_seen] = true
          dispatch[:unknown] = true unless source_path(event.path) || test_path(event.path)
        end
      end
      native = event.event == :c_call
      definition = method_definition(event)
      source = source_path(definition&.first)
      cached_receiver = object_sources(event.self)
      direct_caller = frames.last
      external_entry =
        !native && !source && @active_test && direct_caller &&
          (direct_caller[:source] || direct_caller.fetch(:test)) &&
          !(
            Module === event.defined_class &&
              Module
                .instance_method(:name)
                .bind_call(event.defined_class)
                .to_s
                .match?(/\A(?:RSpec|Mocha|TestProf)(?:::|\z)/)
          )
      state_operation = %i[
        const_added
        const_set
        instance_variable_get
        instance_variable_set
        remove_instance_variable
        class_variable_get
        class_variable_set
        remove_class_variable
        require
        require_relative
        load
      ].include?(event.method_id)
      native_scope = @scopes[Thread.current].last
      inherited_native_context =
        @loading[Thread.current].zero? && native_scope && native_scope[:external_context]
      native_boundary =
        native && !source && @active_test &&
          (source_path(event.path) || test_path(event.path) || inherited_native_context)
      if native && !source && !native_boundary && cached_receiver.empty? && !dynamic &&
           !state_operation &&
           !(@active_test && @external_owners[event.self] && definition&.first) &&
           !(
             mutation?(event) &&
               (
                 Module === event.self || Thread === event.self || IO === event.self ||
                   OBJECT_IDENTITY.bind_call(event.self, ENV) ||
                   (
                     [Hash, Array, Set].any? { |type| type === event.self } &&
                       (source_path(event.path) || test_path(event.path))
                   )
               )
           )
        frames << nil
        return
      end
      if !native && !source && cached_receiver.empty? && !test_path(event.path) && !dynamic &&
           !state_operation &&
           !(
             @active_test &&
               (Module === event.self || external_entry || @external_owners[event.self])
           )
        frames << nil
        return
      end
      locations = caller_locations(2, 2)
      caller_path = native ? event.path : locations[1]&.absolute_path
      caller_source = source_path(caller_path)
      scopes = @scopes[Thread.current]
      scope = scopes.last
      inputs =
        source ? [source] : (native || state_sources?(cached_receiver)) ? cached_receiver : []
      test_code = !native && test_path(event.path)
      known_context = source || !inputs.empty? || caller_source || test_path(caller_path)
      mutating = native && known_context && mutation?(event)
      constant_event = event.method_id == :const_added && caller_source
      reflective = %i[
        instance_variable_get
        instance_variable_set
        remove_instance_variable
        class_variable_get
        class_variable_set
        remove_class_variable
      ].include?(event.method_id)
      loading_call = %i[require require_relative load].include?(event.method_id)
      dynamic_unknown =
        (
          (dynamic || reflective) &&
            (caller_source || scope&.fetch(:source) || test_path(caller_path))
        ) ||
          (
            loading_call && (caller_source || test_path(caller_path)) &&
              explicit_loading?(
                path: caller_path,
                line: native ? event.lineno : locations[1].lineno,
              )
          )
      native_dispatch = native && dynamic && scope && scope.fetch(:test)
      external_effects =
        if @active_test && (@loading[Thread.current].zero? || @external_owners[event.self]) &&
             !source && !native &&
             (Module === event.self || external_entry || @external_owners[event.self]) &&
             (
               caller_source || scope&.fetch(:source) || test_path(caller_path) ||
                 @external_owners[event.self]
             )
          if File.file?(event.path)
            unless test_path(event.path)
              effects(
                path: event.path,
                line: event.lineno,
                block: event.event == :b_call,
                method_name: event.method_id,
              )
            end
          elsif external_entry
            { reads: [], writes: [], unknown: true }
          end
        end
      external_state =
        external_effects &&
          (
            external_effects.fetch(:unknown) || external_effects.fetch(:reads).any? ||
              external_effects.fetch(:writes).any? || external_entry
          )
      @external_owners[event.self] = true if external_effects &&
        external_effects.fetch(:writes).any?
      external_accessor =
        @active_test && !source && native && @external_owners[event.self] && definition&.first
      container = [Hash, Array, Set, String].any? { |type| type === event.self }
      opaque_cache = !container && state_sources?(inputs)
      opaque_mutation =
        !source && known_context &&
          (
            opaque_cache ||
              (
                mutation?(event) && (native || !external_effects) &&
                  (
                    Module === event.self || Thread === event.self || IO === event.self ||
                      OBJECT_IDENTITY.bind_call(event.self, ENV)
                  )
              )
          )
      default_hook =
        (
          event.defined_class == Module &&
            %i[method_added method_removed method_undefined const_added].include?(event.method_id)
        ) ||
          (
            event.defined_class == BasicObject &&
              %i[
                singleton_method_added
                singleton_method_removed
                singleton_method_undefined
              ].include?(event.method_id)
          )
      mapped_mutation =
        mutating && [Hash, Array, Set, String].include?(event.defined_class) &&
          state_sources?(inputs)
      opaque_native =
        native_boundary && !external_accessor && !loading_call && !default_hook &&
          !mapped_mutation && !tracked_hash_read?(event: event, inputs: inputs)
      possible_unknown =
        opaque_native || opaque_mutation ||
          (mutating && [Hash, Array, Set].any? { |type| type === event.self })
      if !source && inputs.empty? && !test_code && !constant_event && !dynamic_unknown &&
           !native_dispatch && !possible_unknown && !external_state && !external_accessor &&
           event.method_id != :const_set
        frames << nil
        return
      end
      data =
        (
          if (source || test_code) && !native
            effects(
              path: definition.first,
              line: definition.last,
              block: event.event == :b_call,
              method_name: event.method_id,
            )
          else
            external_effects || { reads: [], writes: [], unknown: false }
          end
        )
      example = active_example if source || test_code
      example_location = example && example.metadata[:block]&.source_location
      example_boundary =
        test_code && event.event == :b_call && example_location &&
          example_location.first == event.path &&
          (example_location.last == event.lineno || data[:range]&.cover?(example_location.last)) &&
          !scopes.any? { |parent| OBJECT_IDENTITY.bind_call(parent[:example], example) }
      test_scope =
        test_code &&
          (
            if example
              example_boundary
            else
              data.fetch(:test_boundary, false) || !scopes.any? { |parent| parent.fetch(:test) }
            end
          )
      reads = data.fetch(:reads)
      writes = data.fetch(:writes)
      if (source || external_accessor) && native
        name = event.method_id.to_s
        begin
          accessor_variable = :"@#{name.delete_suffix("=")}"
          Object.instance_method(:instance_variable_defined?).bind_call(
            event.self,
            accessor_variable,
          )
          if name.end_with?("=")
            writes = [accessor_variable]
          else
            reads = [accessor_variable]
          end
        rescue NameError
          data = data.merge(unknown: true)
        end
      end
      method_node =
        if source && native
          "__method__/#{source}/native/#{event.method_id}"
        elsif source && data[:method_index]
          "__method__/#{source}/#{data.fetch(:method_index)}"
        else
          source
        end
      read_slots =
        reads.map { |variable| record_state_slot(receiver: event.self, variable: variable) }
      write_slots =
        writes.map { |variable| record_state_slot(receiver: event.self, variable: variable) }
      reads.each_with_index do |variable, index|
        value = Object.instance_method(:instance_variable_get).bind_call(event.self, variable)
        record_object(value: value, sources: [method_node, read_slots[index]].compact, field: true)
      end
      inherited_slots = inputs.grep(%r{\A__state__/})
      read_slots |= inherited_slots
      write_slots |= inherited_slots if mutating
      @observed_sources.add(source) if source
      inputs = inputs.map { |path| path == source ? method_node : path } if source
      dependencies = @dependency_sets.build(inputs).merge(read_slots)
      dependencies.merge(scope.fetch(:inputs)) if external_entry && scope && event.parameters.any?
      unless test_scope
        scopes.reverse_each do |parent|
          parent.fetch(:inputs).merge(dependencies)
          break if parent.fetch(:test)
        end
      end
      @tests[@active_test].merge(dependencies | [source].compact) if @active_test
      top_level =
        caller_source &&
          ["<top (required)>", "<main>"].include?(locations[native ? 0 : 1]&.base_label)
      deferred_fixture =
        test_code && event.event == :b_call &&
          (!data.fetch(:test_boundary, false) || data.fetch(:uncertain_scope, false)) &&
          defined?(RSpec) && RSpec.respond_to?(:current_scope) &&
          %i[before_context_hook before_example_hook before_all].include?(RSpec.current_scope)
      initializing =
        !@active_test || Thread.current != @test_thread || deferred_fixture ||
          (example && !test_path(example_location&.first)) || @initializing[Thread.current] > 0 ||
          @loading[Thread.current] > 0 || top_level ||
          (!example_boundary && scope && scope.fetch(:initializing))
      if initializing
        @initialization_sources.merge(dependencies)
        @initialization_lines[source].add(data.fetch(:body_line)) if source && data[:body_line]
      end
      constant_mutation = mutating && cache_value?(event.self) && @constants[event.self]
      unknown_mutation =
        mutating && inherited_slots.empty? && [Hash, Array, Set].any? { |type| type === event.self }
      unknown =
        opaque_native || opaque_mutation || data.fetch(:unknown) || constant_mutation ||
          (unknown_mutation && (caller_source || test_path(caller_path))) || dynamic_unknown ||
          (event.method_id == :const_set && (caller_source || test_path(caller_path)))
      external_writes = external_effects && writes.any?
      entry_line = external_entry_line(event) if external_writes
      argument_inputs =
        example_boundary || !scope ? @dependency_sets.build : scope.fetch(:argument_inputs)
      if !native && !example_boundary && scope && event.parameters.any?
        argument_inputs |= scope.fetch(:inputs)
      end
      frame =
        if source || !inputs.empty? || external_state || external_accessor || test_code ||
             constant_event || native_dispatch || (unknown && scope)
          {
            source: source || (unknown ? caller_source : nil),
            native: native,
            receiver: event.self,
            inputs: dependencies,
            writes: write_slots,
            variables: writes,
            external_write_path: external_writes ? event.path : nil,
            external_write_lines: external_writes ? data.fetch(:write_lines) : nil,
            executed_writes:
              (
                if external_writes
                  (
                    if entry_line
                      data
                        .fetch(:write_lines)
                        .filter_map do |variable, ranges|
                          variable if ranges.any? { |range| range.cover?(entry_line) }
                        end
                    else
                      writes
                    end
                  ).to_set
                else
                  nil
                end
              ),
            external_context:
              !!((external_entry && external_effects) || scope&.fetch(:external_context, false)),
            unknown: !!unknown,
            parent: scope,
            test: !!test_scope,
            initializing: !!initializing,
            example: example_boundary ? example : nil,
            opaque_without_arguments:
              opaque_mutation && !mutating && !dynamic_unknown && !data.fetch(:unknown) &&
                event.parameters.empty?,
            argument_inputs: argument_inputs,
            native_dispatch: !!native_dispatch,
            callback_seen: false,
            argument_write: write_slots.any? && (native || event.parameters.any?),
            body_line: source ? data[:body_line] : nil,
            method_node: method_node,
            constant_owner: constant_event ? event.self : nil,
          }
        end
      frames << frame
      scopes << frame if frame
      if @active_test && frame && !native && frame.fetch(:unknown) &&
           source&.start_with?("app/", "lib/", "plugins/", "migrations/")
        @coarse_depth[Thread.current] = 1
      end
      if frame && external_writes
        @external_write_depth += 1
        @external_line_trace.enable if @external_write_depth == 1
      end
    end
  end
end
