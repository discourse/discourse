# frozen_string_literal: true

module DiscourseAi
  module Evals
    class Features
      def initialize(modules: DiscourseAi::Configuration::Module.all, output: $stdout)
        @modules = modules
        @output = output
      end

      def print
        module_entries.each do |module_name, entries|
          output.puts module_name

          if entries.empty?
            output.puts "  - no registered features"
            next
          end

          entries.each { |entry| output.puts "  - #{entry[:key]}" }
        end
      end

      def feature_map(evals)
        grouped_evals = Array(evals).group_by { |eval| eval.feature }
        grouped_evals.transform_values { |mapped_evals| mapped_evals.map(&:id).sort }
      end

      def feature_keys
        entries.map { |entry| entry[:key] }
      end

      def valid_feature_key?(key)
        feature_keys.include?(key)
      end

      private

      attr_reader :modules, :output

      def module_entries
        @module_entries ||= modules.map { |mod| [mod.name, entries_for_module(mod)] }
      end

      def entries
        @entries ||= module_entries.flat_map { |(_, m_entries)| m_entries }
      end

      def entries_for_module(mod)
        feature_entries_by_module[mod] ||= Array(mod.features).map do |feature|
          { key: feature_key(mod, feature), module_name: mod.name }
        end
      end

      def feature_entries_by_module
        @feature_entries_by_module ||= {}
      end

      def feature_key(mod, feature)
        "#{mod.name}:#{feature.name}"
      end
    end
  end
end
