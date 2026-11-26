# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::LinkageInputs do
  subject(:inputs) { described_class.new(request, resource:, relationship_name:) }

  let(:group_resource) do
    Class.new(JsonApiKit::Resource) do
      type :groups
      has_one :smtp_updated_by, resource: UserResource, writable: true
      has_many :readonly_users, resource: UserResource
      has_one :secret_editor,
              resource: UserResource,
              readable: ->(_guardian) { false },
              writable: true
    end
  end
  let(:resource) { group_resource.new(guardian: Guardian.new, edition:) }
  let(:edition) { JsonApiKit::Edition.current }
  let(:relationship_name) { "smtp_updated_by" }
  let(:request_method) { "PATCH" }
  let(:query_parameters) { {} }
  let(:request) { instance_double(ActionDispatch::Request, request_method:, query_parameters:) }

  describe ".new" do
    context "when the relationship is unknown" do
      let(:relationship_name) { "unknown" }

      it "raises NotFound" do
        expect { inputs }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when POST targets an unreadable writable relationship" do
      let(:relationship_name) { "secret_editor" }
      let(:request_method) { "POST" }

      it "hides the unreadable relationship" do
        expect { inputs }.to raise_error(JsonApiKit::NotFound)
      end
    end

    context "when the relationship is read-only" do
      let(:relationship_name) { "readonly_users" }

      it "reports the client relationship name" do
        expect { inputs }.to raise_error(
          JsonApiKit::Forbidden,
          "readonlyUsers is not a writable relationship.",
        )
      end
    end

    context "when POST targets a to-one relationship under its previous name" do
      let(:request_method) { "POST" }
      let(:edition) { JsonApiKit::Edition.new([rename.new(__FILE__)]) }
      let(:rename) do
        Class.new(JsonApiKit::VersionChange) do
          resource :groups do
            renamed_relationship from: :editor, to: :smtp_updated_by
          end
        end
      end

      it "reports the unsupported method using the previous relationship name" do
        expect { inputs }.to raise_error(
          JsonApiKit::Forbidden,
          "editor cannot be updated with POST.",
        )
      end
    end

    context "when include names an unknown relationship" do
      let(:query_parameters) { { "include" => "unknown" } }

      it "rejects the parameter before reading the body" do
        expect { inputs }.to raise_error(
          JsonApiKit::Request::Invalid,
          "There is no parameter named include.",
        )
      end
    end
  end

  describe "#body" do
    subject(:body) { inputs.body }

    let(:json) { { data: { type: "users", id: "0012" } }.to_json }

    before { allow(request).to receive(:raw_post).and_return(json) }

    context "when PATCH sets a to-one relationship" do
      it "preserves the identifier string" do
        expect(body.parameters).to eq(smtp_updated_by_id: "0012")
      end
    end
  end
end
