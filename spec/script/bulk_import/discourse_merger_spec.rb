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

    describe "#fix_category_descriptions" do
      fab!(:category)
      fab!(:old_description_topic, :topic)
      fab!(:new_description_topic, :topic)

      let(:merger) do
        build_merger(
          categories: {
            999_999 => category.id,
          },
          topics: {
            old_description_topic.id => new_description_topic.id,
          },
        )
      end

      before do
        category.update_columns(topic_id: old_description_topic.id)
        category.custom_fields["import_id"] = "999999"
        category.save_custom_fields
      end

      it "remaps the description topic of merged categories" do
        merger.fix_category_descriptions

        expect(category.reload.topic_id).to eq(new_description_topic.id)
      end

      it "remaps categories whose copied attributes no longer pass validation" do
        category.update_columns(color: "zzzzzz")

        merger.fix_category_descriptions

        expect(category.reload.topic_id).to eq(new_description_topic.id)
      end
    end
  end
end
