# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Contract::Individual, type: :model do
  subject(:contract) { described_class.for(params, resource:, glossary:) }

  let(:params) { {} }
  let(:glossary) { JsonApiKit::Glossary.kit }
  let(:related) do
    Class.new(JsonApiKit::Resource) do
      model User
      type :users
    end
  end
  let(:resource) do
    users = related
    Class.new(JsonApiKit::Resource) do
      has_one :user, resource: users
      model Topic
      type :topics
      sort :created_at
      filter :title
      anchor :id
    end
  end

  describe "Unknown parameters" do
    context "when a parameter is unknown" do
      let(:params) { { fieldsets: { topics: %w[title] } } }

      it "adds an error on the parameter" do
        expect(contract).to be_invalid
        expect(contract.errors).to include(:fieldsets)
      end
    end

    context "when a parameter belongs to a listing" do
      let(:params) do
        {
          sort: {
            created_at: :asc,
          },
          filter: {
            title: "a topic",
          },
          page: {
            anchor: {
              id: 12,
            },
            size: 2,
          },
        }
      end

      it "adds an error for each of them, though the resource declares them" do
        expect(contract).to be_invalid
        expect(contract.errors).to include(:sort, :filter, :page)
      end
    end
  end

  describe "Including" do
    it { is_expected.to allow_value(nil, [], %w[user]).for(:include) }
    it { is_expected.to allow_value("", [""]).for(:include) }
    it { is_expected.not_to allow_value(%w[secrets], %w[user.groups]).for(:include) }
  end

  describe "Fieldsets" do
    it { is_expected.to allow_value(nil, {}, { topics: %w[title created_at] }).for(:fields) }
    it { is_expected.to allow_value({ topics: [] }).for(:fields) }

    it do
      is_expected.not_to allow_value("title", [1], { topics: 42 }, { topics: "title" }).for(:fields)
    end
  end
end
