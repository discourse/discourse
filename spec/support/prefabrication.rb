# frozen_string_literal: true

# `fab!` defines a fabricated record for an example group. By default it's backed
# by TestProf's `let_it_be` (fabricated once per group); with PREFABRICATION=0 it
# falls back to a plain per-example `let!`.

if ENV["PREFABRICATION"] == "0"
  module Prefabrication
    def fab!(name, fabricator_name = nil, **opts, &blk)
      blk ||= proc { Fabricate(fabricator_name || name) }
      let!(name, &blk)
    end
  end
else
  require "test_prof/recipes/rspec/let_it_be"
  require "test_prof/before_all/adapters/active_record"

  TestProf::BeforeAll.configure { |config| config.after(:begin) { TestSetup.test_setup } }

  module Prefabrication
    def fab!(name, fabricator_name = nil, **opts, &blk)
      blk ||= proc { Fabricate(fabricator_name || name) }
      let_it_be(name, refind: true, **opts, &blk)
    end
  end
end

RSpec.configure { |config| config.extend(Prefabrication) }
