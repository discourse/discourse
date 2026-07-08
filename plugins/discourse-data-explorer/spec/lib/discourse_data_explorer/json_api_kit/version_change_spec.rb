# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::VersionChange do
  subject(:change) do
    Class.new(described_class) do
      version "2026-06-15"
      description "The `foo` attribute of the things resource is renamed to `bar`."

      resource :things do
        up { |resource| resource[:attributes][:bar] = resource[:attributes].delete(:foo) }
        down { |resource| resource[:attributes][:foo] = resource[:attributes].delete(:bar) }
      end

      document { down { |document| document[:meta] = (document[:meta] || {}).merge(legacy: true) } }
    end
  end

  it "exposes its version as an ApiVersion" do
    expect(change.version).to eq(DiscourseDataExplorer::JsonApiKit::ApiVersion.parse("2026-06-15"))
  end

  it "exposes its description" do
    expect(change.description).to include("renamed to `bar`")
  end

  it "cannot be instantiated" do
    expect { change.new }.to raise_error(NoMethodError)
  end

  it "lists the resource types it targets" do
    expect(change.resource_types).to contain_exactly("things")
  end

  describe ".transform_for" do
    context "with the down direction" do
      let(:resource) { { type: :things, attributes: { bar: "x" } } }

      before { change.transform_for(:down, type: "things").call(resource) }

      it "runs the declared down transform" do
        expect(resource[:attributes]).to eq(foo: "x")
      end
    end

    context "with the up direction" do
      let(:resource) { { type: :things, attributes: { foo: "x" } } }

      before { change.transform_for(:up, type: "things").call(resource) }

      it "runs the declared up transform" do
        expect(resource[:attributes]).to eq(bar: "x")
      end
    end

    context "with an untargeted type" do
      it "returns nil" do
        expect(change.transform_for(:down, type: "users")).to be_nil
      end
    end
  end

  describe ".document_transform" do
    context "with a declared direction" do
      let(:document) { { data: [] } }

      before { change.document_transform(:down).call(document) }

      it "runs the declared transform" do
        expect(document[:meta]).to eq(legacy: true)
      end
    end

    context "with an undeclared direction" do
      it "returns nil" do
        expect(change.document_transform(:up)).to be_nil
      end
    end
  end
end
