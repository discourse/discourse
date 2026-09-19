# frozen_string_literal: true

RSpec.describe JsonApiKit::Sideloads do
  subject(:sideloads) { described_class.for(relationships, paths:, rows:, request:, schema:) }

  fab!(:author, :user)
  fab!(:category) { Fabricate(:category, name: "Where the topic sits") }
  fab!(:topic) do
    Fabricate(:topic, user: author, category:, title: "A topic read with two relations")
  end

  let(:groups_resource) do
    Class.new(JsonApiKit::Resource) do
      model Group
      type :groups
    end
  end
  let(:users_resource) do
    related = groups_resource

    Class.new(JsonApiKit::Resource) do
      model User
      type :users
      has_many :groups, resource: related
    end
  end
  let(:categories_resource) do
    Class.new(JsonApiKit::Resource) do
      model Category
      type :categories
    end
  end
  let(:to_one) { JsonApiKit::Declarations::Relationship::ToOne }
  let(:relationships) do
    [
      to_one.new(:user, resource: users_resource),
      to_one.new(:category, resource: categories_resource),
    ]
  end
  let(:paths) { JsonApiKit::Paths.new(nil) }
  let(:rows) { [JsonApiKit::Pagination::Row.new(record: topic, segment: nil)] }
  let(:request) { JsonApiKit::Request::Collection.new({}, guardian: Guardian.new) }
  let(:schema) { JsonApiKit::Schema.new(Topic) }

  describe "#linkage_for" do
    subject(:linkage) { sideloads.linkage_for(rows.first) }

    let(:related_rows) { linkage.transform_values { it.records.map(&:record) } }

    it "holds one linkage under the name of each relationship" do
      expect(linkage.keys).to eq(%w[user category])
    end

    it "holds what the row relates to under each of them" do
      expect(related_rows).to eq("user" => [author], "category" => [category])
    end

    context "when a reading renders no relationship" do
      let(:relationships) { [] }

      it "holds nothing" do
        expect(linkage).to be_empty
      end
    end

    context "when a path reads past a relationship" do
      let(:paths) { JsonApiKit::Paths.new(%w[user.groups]) }
      let(:forwarded) { [] }

      before do
        allow(JsonApiKit::Sideload).to receive(:new) { |_, paths:, **| forwarded << paths.to_a }
      end

      it "gives each relationship the paths that continue through it" do
        sideloads
        expect(forwarded.map { it.map(&:to_s) }).to eq([%w[user.groups], []])
      end
    end
  end
end
