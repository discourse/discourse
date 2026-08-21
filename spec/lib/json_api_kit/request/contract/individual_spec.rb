# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Contract::Individual, type: :model do
  subject(:contract) do
    described_class.new(
      **params,
      options: {
        resource:,
        raw_parameters: params.with_indifferent_access,
      },
    )
  end

  let(:params) { {} }
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

      it "refuses the parameter" do
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
          anchor: {
            id: 12,
          },
          page: {
            size: 2,
          },
        }
      end

      it "refuses each of them, though the resource declares them" do
        expect(contract).to be_invalid
        expect(contract.errors).to include(:sort, :filter, :anchor, :page)
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
    it { is_expected.to allow_value({ topics: "title" }, { topics: "" }).for(:fields) }
    it { is_expected.not_to allow_value("title", [1], { topics: 42 }).for(:fields) }
  end
end
