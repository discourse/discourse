# frozen_string_literal: true

RSpec.describe JsonApiKit::Request do
  subject(:request) do
    described_class::Collection.new(params, guardian:, edition: JsonApiKit::Edition.current)
  end

  let(:params) { {} }
  let(:guardian) { Guardian.new }

  describe "#for_sideload" do
    subject(:for_sideload) do
      request.for_sideload(JsonApiKit::Paths.new(%w[groups]), through: "user")
    end

    let(:params) do
      {
        fields: {
          users: %w[username],
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
      subject(:request) do
        described_class::Individual.new(params, guardian:, edition: JsonApiKit::Edition.current)
      end

      let(:params) { { id: 12, fields: { users: %w[username] } } }

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

      it "requires a resolved ordering" do
        expect { ordering }.to raise_error(KeyError, /sort/)
      end
    end

    context "when the request has an explicit empty ordering" do
      let(:params) { { sort: {} } }

      it "preserves the empty ordering" do
        expect(ordering).to be_empty
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

    let(:params) { { fields: { topics: %w[title] } } }

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
    let(:params) { { page: { size: 2, after: "opaque-cursor" } } }

    it "preserves the pagination parameters for the adapter" do
      expect(request.page).to eq(size: 2, after: "opaque-cursor")
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
