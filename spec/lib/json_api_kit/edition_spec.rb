# frozen_string_literal: true

RSpec.describe JsonApiKit::Edition do
  subject(:edition) { described_class.for(version) }

  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE }
  let(:title) { JsonApiKit::Name::Field.new(value: "title", type: "topics") }
  let(:member_name) { edition.glossary.member_name(title).value }
  let(:ordering) { edition.default_sorts.for(resource) }
  let(:version_change) do
    Class
      .new(JsonApiKit::VersionChange) do
        resource :topics do
          renamed_attribute from: :heading, to: :title
          changed_default_sort from: { created_at: :desc }
        end
      end
      .new(__FILE__)
  end
  let(:changes) { [version_change] }
  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      sort :title
      default_sort title: :asc
    end
  end

  before do
    allow(JsonApiKit::VersionChanges.core).to receive(:after).with(version).and_return(changes, [])
  end

  describe ".for" do
    it "selects one change set for names and defaults" do
      expect([member_name, ordering]).to eq(["heading", { "created_at" => :desc }])
    end

    it "selects the pin's changes once" do
      edition.glossary
      edition.default_sorts
      expect(JsonApiKit::VersionChanges.core).to have_received(:after).with(version).once
    end

    context "when the registry's array changes after construction" do
      before do
        edition
        changes.clear
      end

      it "retains the edition's selected changes" do
        expect([member_name, ordering]).to eq(["heading", { "created_at" => :desc }])
      end
    end
  end

  describe ".current" do
    subject(:edition) { described_class.current }

    it "uses current names and defaults" do
      expect([member_name, ordering]).to eq(["title", { "title" => :asc }])
    end
  end

  describe "#glossary" do
    before { allow(JsonApiKit::Glossary).to receive(:new).and_call_original }

    it "builds the glossary with casing and version rules" do
      edition.glossary
      expect(JsonApiKit::Glossary).to have_received(:new).with(
        [JsonApiKit::Glossary::CasingRule, an_instance_of(JsonApiKit::Glossary::VersionRule)],
      )
    end

    it "retains the glossary for the edition" do
      expect(edition.glossary).to equal(edition.glossary)
    end
  end

  describe "#default_sorts" do
    it "retains the resolver for the edition" do
      expect(edition.default_sorts).to equal(edition.default_sorts)
    end
  end
end
