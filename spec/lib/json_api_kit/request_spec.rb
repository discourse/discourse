# frozen_string_literal: true

RSpec.describe JsonApiKit::Request do
  subject(:request) { described_class::Collection.new(params, guardian:) }

  let(:params) { {} }
  let(:guardian) { Guardian.new }

  describe "#scope" do
    subject(:scope) { request.scope(from: Topic.all) }

    fab!(:topic) { Fabricate(:topic, title: "The row an id names") }

    it "returns every row on offer" do
      expect(scope).to eq(Topic.all.to_a)
    end

    context "when a caller asks for one record" do
      subject(:request) { described_class::Individual.new(params, guardian:) }

      let(:params) { { id: topic.id } }

      it "returns only the row with that id" do
        expect(scope).to eq([topic])
      end
    end
  end

  describe "#for_sideload" do
    subject(:for_sideload) { request.for_sideload(JsonApiKit::Paths.new(%w[groups])) }

    let(:params) do
      {
        fields: {
          users: %i[username],
        },
        include: %w[user.groups],
        sort: {
          created_at: :desc,
        },
        filter: {
          title: "a title",
        },
        page: {
          size: 2,
        },
      }
    end

    it "asks for the paths of the sideload" do
      expect(for_sideload[:include].map(&:to_s)).to eq(%w[groups])
    end

    it "asks for the fields of every type" do
      expect(for_sideload[:fields]).to eq("users" => %w[username])
    end

    it "asks nothing else of the related resource" do
      expect(for_sideload.keys).to contain_exactly(:fields, :include)
    end

    context "when a caller asks for one record" do
      subject(:request) { described_class::Individual.new(params, guardian:) }

      let(:params) { { id: 12, fields: { users: %i[username] } } }

      it "leaves the id out" do
        expect(for_sideload.keys).to contain_exactly(:fields, :include)
      end
    end
  end

  describe "#including" do
    subject(:including) { request.including }

    let(:params) { { include: %w[user user.groups] } }

    it "returns each path" do
      expect(including.map(&:to_s)).to eq(%w[user user.groups])
    end

    context "when a caller spells the paths as symbols" do
      let(:params) { { include: %i[user] } }

      it "returns the same paths" do
        expect(including.map(&:to_s)).to eq(%w[user])
      end
    end

    context "when there is no include parameter" do
      let(:params) { {} }

      it "returns no path" do
        expect(including).to be_empty
      end
    end
  end

  describe "#ordering" do
    subject(:ordering) { request.ordering }

    let(:params) { { sort: { created_at: :desc } } }

    it "returns each sort by name with its direction" do
      expect(ordering).to eq("created_at" => :desc)
    end

    context "when there is no sort parameter" do
      let(:params) { {} }

      it "returns no sort" do
        expect(ordering).to be_empty
      end
    end

    context "when a caller spells the parameters as strings" do
      let(:params) { { "sort" => { "created_at" => "desc" } } }

      it "returns the same ordering" do
        expect(ordering).to eq("created_at" => :desc)
      end
    end
  end

  describe "#filtering" do
    subject(:filtering) { request.filtering }

    let(:params) { { filter: { title: "a title" } } }

    it "returns each filter by name with its value" do
      expect(filtering).to eq("title" => "a title")
    end

    context "when there is no filter parameter" do
      let(:params) { {} }

      it "returns no filter" do
        expect(filtering).to be_empty
      end
    end
  end

  describe "#fields" do
    subject(:fields) { request.fields }

    let(:params) { { fields: { topics: [:title] } } }

    it "returns the fields of each type" do
      expect(fields).to eq("topics" => %w[title])
    end

    context "when there is no fields parameter" do
      let(:params) { {} }

      it "returns no field" do
        expect(fields).to be_empty
      end
    end
  end

  describe "#page" do
    subject(:page) { request.page }

    it "returns the page at the start of the listing" do
      expect(page).to be_a(JsonApiKit::Page::Requested::First)
    end

    context "when the page holds an after cursor" do
      let(:params) { { page: { after: JsonApiKit::Pagination::Cursor.new([12]).to_s } } }

      it "returns the page that carries on from it" do
        expect(page).to be_a(JsonApiKit::Page::Requested::After)
      end
    end

    context "when the page holds a before cursor" do
      let(:params) { { page: { before: JsonApiKit::Pagination::Cursor.new([12]).to_s } } }

      it "returns the page before it" do
        expect(page).to be_a(JsonApiKit::Page::Requested::Before)
      end
    end

    context "when the cursor cannot be read" do
      let(:params) { { page: { after: "not a cursor" } } }

      it "refuses the request" do
        expect { page }.to raise_error(ArgumentError)
      end
    end

    context "when there is an anchor parameter" do
      let(:params) { { page: { anchor: { id: 12 } } } }

      it "returns the page around it" do
        expect(page).to be_a(JsonApiKit::Page::Requested::Around)
      end
    end
  end

  describe "#anchoring" do
    subject(:anchoring) { request.anchoring }

    let(:params) { { page: { anchor: { id: 12 } } } }

    it "returns that anchor" do
      expect(anchoring.name).to eq("id")
    end

    context "when there is no anchor parameter" do
      let(:params) { {} }

      it "returns nothing" do
        expect(anchoring).to be_nil
      end
    end
  end

  describe "#guardian" do
    subject(:request_guardian) { request.guardian }

    it "returns whoever asks" do
      expect(request_guardian).to be(guardian)
    end
  end
end
