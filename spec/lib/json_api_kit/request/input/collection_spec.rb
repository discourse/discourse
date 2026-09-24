# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Input::Collection do
  subject(:input) { described_class.new(parameters, resource:, edition:) }

  let(:parameters) { {} }
  let(:edition) { JsonApiKit::Edition.new([version_change]) }
  let(:version_change) do
    Class
      .new(JsonApiKit::VersionChange) do
        resource :topics do
          renamed_attribute from: :posted_at, to: :created_at
          changed_default_sort from: { posted_at: :desc }
        end
      end
      .new(__FILE__)
  end
  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      attribute :created_at
      attribute :title
      sort :created_at
      sort :title
      default_sort title: :asc
    end
  end

  describe "#to_h" do
    subject(:ordering) { input.to_h.fetch(:sort) }

    before { input.invalid? }

    it "supplies the historical default in current names" do
      expect(ordering).to eq("created_at" => :desc)
    end

    context "when the client supplies a sort" do
      let(:parameters) { { sort: "postedAt" } }

      it "translates the explicit ordering" do
        expect(ordering).to eq("created_at" => :asc)
      end
    end

    context "when the client supplies an empty sort" do
      let(:parameters) { { sort: "" } }

      it "supplies the historical default" do
        expect(ordering).to eq("created_at" => :desc)
      end
    end
  end

  describe "#invalid?" do
    it { is_expected.not_to be_invalid }

    context "when the client supplies a sort with an invalid shape" do
      let(:parameters) { { sort: false } }

      it { is_expected.to be_invalid }
    end

    context "when an explicit sort accompanies an invalid historical default" do
      let(:parameters) { { sort: "title" } }
      let(:version_change) do
        Class
          .new(JsonApiKit::VersionChange) do
            resource(:topics) { changed_default_sort from: { unknown: :asc } }
          end
          .new(__FILE__)
      end

      it "validates the explicit sort without resolving the unused default" do
        expect(input).not_to be_invalid
      end
    end
  end

  describe "#refusals" do
    subject(:refusals) { input.refusals }

    let(:parameters) { { sort: "neverDeclared" } }

    before { input.invalid? }

    it "reports validation errors in the client's vocabulary" do
      expect(refusals.sole).to have_attributes(
        detail: "There is no sort named neverDeclared.",
        source: {
          parameter: "sort",
        },
      )
    end
  end

  describe "#fieldsets" do
    subject(:attributes) do
      input.fieldsets.keep("topics", "postedAt" => "date", "title" => "A topic")
    end

    let(:parameters) { { fields: { topics: "postedAt" } } }

    it "retains the fieldset in the client's vocabulary" do
      expect(attributes).to eq("postedAt" => "date")
    end
  end
end
