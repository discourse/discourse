# frozen_string_literal: true

RSpec.describe JsonApiKit::RelationshipReading do
  describe ".relationship" do
    subject(:declare_relationship) { controller.relationship(name) }

    let(:controller) { Class.new(JsonApiKit::RelationshipsController) }
    let(:resource) do
      Class.new(JsonApiKit::Resource) { has_one :smtp_updated_by, resource: JsonApiKit::Resource }
    end

    context "when the controller declares its resource" do
      before { controller.resource(resource) }

      context "when the name uses hyphens" do
        let(:name) { :"smtp-updated-by" }

        it "stores the resource's relationship name" do
          expect { declare_relationship }.to change(controller, :declared_relationship).to(
            "smtp_updated_by",
          )
        end
      end

      context "when the resource has no such relationship" do
        let(:name) { :unknown }

        it "rejects the name at declaration time" do
          expect { declare_relationship }.to raise_error(
            JsonApiKit::Resource::UnknownRelationship,
            /unknown/,
          )
        end
      end
    end

    context "when the controller has no resource" do
      let(:name) { :users }

      it "requires a resource declaration" do
        expect { declare_relationship }.to raise_error(
          JsonApiKit::EndpointController::Serving::MissingDeclaration,
        )
      end
    end
  end
end
