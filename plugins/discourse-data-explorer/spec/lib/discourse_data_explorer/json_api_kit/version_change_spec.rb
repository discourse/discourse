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
    it "runs the down transform on a resource hash" do
      resource = { type: :things, attributes: { bar: "x" } }

      change.transform_for(:down, type: "things").call(resource)

      expect(resource[:attributes]).to eq(foo: "x")
    end

    it "runs the up transform on a resource hash" do
      resource = { type: :things, attributes: { foo: "x" } }

      change.transform_for(:up, type: "things").call(resource)

      expect(resource[:attributes]).to eq(bar: "x")
    end

    it "returns nil for an untargeted type" do
      expect(change.transform_for(:down, type: "users")).to be_nil
    end
  end

  describe ".document_transform" do
    it "returns the declared direction" do
      document = { data: [] }

      change.document_transform(:down).call(document)

      expect(document[:meta]).to eq(legacy: true)
    end

    it "returns nil for an undeclared direction" do
      expect(change.document_transform(:up)).to be_nil
    end
  end
end
