# frozen_string_literal: true

# Retained input scopes only meet their inputs at the versions they serve, so this instantiates
# every shipped resource and collection at every version a client may pin.
RSpec.describe "JSON:API resources at every version" do
  def editions
    [JsonApiKit::Timeline.first, *JsonApiKit::VersionChanges.core.map(&:version)].uniq.map do
      JsonApiKit::Edition.for(it)
    end
  end

  def shipped_resources
    Rails
      .autoloaders
      .main
      .dirs
      .select { it.end_with?("app/resources") }
      .each { Rails.autoloaders.main.eager_load_dir(it) }
    JsonApiKit::Resource.descendants.select do
      it.name.present? && !it.name.start_with?("JsonApiKitSpec")
    end
  end

  def failures(resources)
    listings =
      resources.flat_map do |resource|
        [resource, *resource.collection_names.map { |name| resource.collection(name) }]
      end
    listings
      .product(editions)
      .filter_map do |listing, edition|
        listing.new(guardian: Guardian.new, edition:).verify_input_scope!
        nil
      rescue ArgumentError => error
        error.message
      end
  end

  it "accepts the input scope of every shipped resource and collection at every version" do
    expect(failures(shipped_resources)).to eq([])
  end

  context "when a version change retains an input scope that reads an input it lacks" do
    let(:resource) do
      Class.new(JsonApiKit::Resource) do
        model Topic
        type :topics
        collection(:workable) { input_scope { |topics, _guardian| topics } }
      end
    end
    let(:change_class) do
      Class.new(JsonApiKit::VersionChange) do
        version "2026-09-10"
        description "Workable topics stop reading a filter that never existed."
        resource(:topics) do
          collection(:workable) { changed_input_scope { |topics, _guardian, secrets:| topics } }
        end
      end
    end

    before do
      freeze_time(Date.new(2026, 9, 18))
      allow(JsonApiKit::VersionChanges).to receive(:core).and_return(
        JsonApiKit::VersionChanges.new([change_class.new("2026-09-10_workable.rb")]),
      )
    end

    it "reports it" do
      expect(failures([resource])).to contain_exactly(/secrets/)
    end
  end
end
