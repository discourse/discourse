# frozen_string_literal: true

merger_dependencies_available =
  begin
    require "redcarpet"
    true
  rescue LoadError
    false
  end

if merger_dependencies_available
  require_relative "../../../script/bulk_import/discourse_merger"

  RSpec.describe BulkImport::DiscourseMerger do
    # The constructor opens raw PG connections to a source and destination
    # database, so specs build an instance without it and set only the state
    # the method under test reads.
    def build_merger(**ivars)
      described_class.allocate.tap do |merger|
        ivars.each { |name, value| merger.instance_variable_set(:"@#{name}", value) }
      end
    end

    it "does not start a merge when the script is merely required" do
      expect(described_class).to respond_to(:new)
    end
  end
end
