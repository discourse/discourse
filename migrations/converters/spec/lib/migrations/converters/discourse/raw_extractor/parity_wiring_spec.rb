# frozen_string_literal: true

# The parity specs are tagged `:rails` and only run in the Rails job, so a helper
# one of them references but never defines goes unnoticed until CI — a required
# keyword added to `RawExtractor` breaks every example in the file at once, and
# nothing here says so. RSpec loads the file either way, which is enough to
# resolve the helpers against the example group and catch that locally.
RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  describe "the parity specs' wiring" do
    # The name sets the extractor requires. Each parity spec passes both, whether
    # or not it is about mentions or hashtags.
    let(:name_set_helpers) { %i[mention_names hashtag_names] }

    # Only the groups RSpec has already loaded — running this file on its own
    # loads no parity spec, and there is nothing to check then.
    let(:parity_groups) do
      RSpec.world.example_groups.select do |group|
        group.metadata[:absolute_file_path].to_s.end_with?("_parity_spec.rb")
      end
    end

    let(:parity_files) { Dir[File.expand_path("*_parity_spec.rb", __dir__)] }

    it "defines the name-set helpers each of them hands to the extractor" do
      skip "no parity spec is loaded — run the suite, not this file alone" if parity_groups.empty?
      # Whoever adds a parity spec gets it checked too, rather than silently not.
      expect(parity_groups.size).to eq(parity_files.size)

      failures =
        parity_groups.flat_map do |group|
          instance = group.new
          file = File.basename(group.metadata[:absolute_file_path])

          name_set_helpers.filter_map do |helper|
            value = instance.public_send(helper)
            unless value.is_a?(Migrations::CompactStringSet)
              "#{file}: #{helper} is a #{value.class}"
            end
          rescue NoMethodError => e
            "#{file}: #{e.message}"
          end
        end

      expect(failures).to be_empty, -> { failures.join("\n") }
    end
  end
end
