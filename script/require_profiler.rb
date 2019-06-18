# frozen_string_literal: true

# Some based on : https://gist.github.com/277289
#
# This is a rudimentary script that allows us to
#  quickly determine if any gems are slowing down startup

require 'benchmark'
require 'fileutils'

module RequireProfiler
  class << self

    attr_accessor :stats

    def profiling_enabled?
      @profiling_enabled
    end

    def profile
      start
      yield
      stop
    end

    def start(tmp_options = {})
      @start_time = Time.now
      [ ::Kernel, (class << ::Kernel; self; end) ].each do |klass|
        klass.class_eval do
          def require_with_profiling(path, *args)
            RequireProfiler.measure(path, caller, :require) { require_without_profiling(path, *args) }
          end
          alias require_without_profiling require
          alias require require_with_profiling

          def load_with_profiling(path, *args)
            RequireProfiler.measure(path, caller, :load) { load_without_profiling(path, *args) }
          end
          alias load_without_profiling load
          alias load load_with_profiling
        end
      end
      # This is necessary so we don't clobber Bundler.require on Rails 3
      Kernel.class_eval { private :require, :load }
      @profiling_enabled = true
    end

    def stop
      @stop_time = Time.now
      [ ::Kernel, (class << ::Kernel; self; end) ].each do |klass|
        klass.class_eval do
          alias require require_without_profiling
          alias load load_without_profiling
        end
      end
      @profiling_enabled = false
    end

    def measure(path, full_backtrace, mechanism, &block)
      # Path may be a Pathname, convert to a String
      path = path.to_s

      @stack ||= []
      self.stats ||= {}

      stat = self.stats.fetch(path) { |key| self.stats[key] = { calls: 0, time: 0, parent_time: 0 } }

      @stack << stat

      time = Time.now
      begin
        output = yield  # do the require or load here
      ensure
        delta = Time.now - time
        stat[:time] += delta
        stat[:calls] += 1
        @stack.pop
        @stack.each do |frame|
          frame[:parent_time] += delta
        end
      end

      output
    end

    def time_block
      start = Time.now
      yield
      Time.now - start
    end

    def gc_analyze
      ObjectSpace.garbage_collect
      gc_duration_start = time_block { ObjectSpace.garbage_collect }
      old_objs = ObjectSpace.count_objects
      yield
      ObjectSpace.garbage_collect
      gc_duration_finish = time_block { ObjectSpace.garbage_collect }
      new_objs = ObjectSpace.count_objects

      puts "New objects: #{(new_objs[:TOTAL] - new_objs[:FREE]) - (old_objs[:TOTAL] - old_objs[:FREE])}"
      puts "GC duration: #{gc_duration_finish}"
      puts "GC impact: #{gc_duration_finish - gc_duration_start}"
    end

  end
end

# RequireProfiler.gc_analyze do
#   # require 'mime-types'
#   require 'highline'
# end
# exit

RequireProfiler.profile do
  Bundler.definition.dependencies.each do |dep|
    begin
      require dep.name
    rescue Exception
      # don't care
    end
  end
end

sorted = RequireProfiler.stats.to_a.sort { |a, b| b[1][:time] - b[1][:parent_time] <=> a[1][:time] - a[1][:parent_time] }

sorted[0..120].each do |k, v|
  puts "#{k} : time #{v[:time] - v[:parent_time]} "
end
