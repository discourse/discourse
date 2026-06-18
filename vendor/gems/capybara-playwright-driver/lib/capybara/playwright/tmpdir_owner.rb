module Capybara
  module Playwright
    module TmpdirOwner
      require 'tmpdir'

      def tmpdir
        return @tmpdir if @tmpdir

        dir = Dir.mktmpdir
        ObjectSpace.define_finalizer(self, TmpdirRemover.new(dir))
        @tmpdir = dir
      end

      def remove_tmpdir
        if @tmpdir
          FileUtils.remove_entry(@tmpdir, true)
          ObjectSpace.undefine_finalizer(self)
          @tmpdir = nil
        end
      end

      class TmpdirRemover
        def initialize(tmpdir)
          @pid = Process.pid
          @tmpdir = tmpdir
        end

        def call(*args)
          return if @pid != Process.pid

          begin
            FileUtils.remove_entry(@tmpdir, true)
          rescue => err
            $stderr.puts err
          end
        end
      end
    end
  end
end
