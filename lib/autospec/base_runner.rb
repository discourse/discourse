# frozen_string_literal: true

module Autospec

  class BaseRunner

    # used when starting the runner - preloading happens here
    def start(opts = {})
    end

    # indicates whether tests are running
    def running?
      true
    end

    # launch a batch of specs/tests
    def run(specs)
    end

    # used when we need to reload the whole application
    def reload
    end

    # used to abort the current run
    def abort
    end

    def failed_specs
      []
    end

    # used to stop the runner
    def stop
    end

  end

end
