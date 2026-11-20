# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Body do
  subject(:body) { described_class.parse(document.to_json, resource:) }

  let(:document) { { "data" => { "type" => "topics", "attributes" => { "title" => nil } } } }
  let(:resource) do
    Class
      .new(JsonApiKit::Resource) do
        model Topic
        type :topics
      end
      .new(guardian: Guardian.new)
  end

  describe "#to_h" do
    before { body.invalid? }

    it "preserves the supplied document" do
      expect(body.to_h).to eq(document)
    end
  end

  describe "#refusals" do
    subject(:refusals) { body.refusals }

    let(:document) { { "data" => { "type" => 123, "attributes" => [] } } }

    before { body.invalid? }

    it "reports each invalid member" do
      expect(refusals.map(&:source)).to contain_exactly(
        { pointer: "/data/type" },
        { pointer: "/data/attributes" },
      )
    end

    it "explains the invalid type" do
      expect(refusals.map(&:detail)).to include("type must be a string.")
    end
  end

  describe "#validation_errors" do
    subject(:validation_errors) { body.validation_errors(errors) }

    let(:document) do
      {
        "data" => {
          "type" => "topics",
          "attributes" => {
            "displaySettings" => {
              "theme" => "",
            },
          },
        },
      }
    end
    let(:errors) { Service::ContractBase.new.errors }

    before { errors.add(attribute, "is invalid") }

    context "when the error applies to the whole contract" do
      let(:attribute) { :base }

      it "points to the submitted resource object" do
        expect(validation_errors.map(&:source)).to contain_exactly(pointer: "/data")
      end
    end

    context "when the error applies to a nested attribute" do
      let(:attribute) { :"display_settings.theme" }

      it "points to the original top-level attribute" do
        expect(validation_errors.map(&:source)).to contain_exactly(
          pointer: "/data/attributes/displaySettings",
        )
      end
    end
  end

  describe "Relationship inputs" do
    let(:document) do
      {
        "data" => {
          "type" => "groups",
          "relationships" => relationships,
          "attributes" => attributes,
        },
      }
    end
    let(:attributes) { {} }
    let(:relationships) { { "users" => { "data" => [identifier] } } }
    let(:identifier) { { "type" => "users", "id" => "0012" } }
    let(:readable) { JsonApiKit::Declarations::Readable::ALWAYS }
    let(:edition) { JsonApiKit::Edition.current }
    let(:users_resource) do
      Class.new(JsonApiKit::Resource) do
        model User
        type :users
      end
    end
    let(:resource) do
      Class
        .new(JsonApiKit::Resource) do
          model Group
          type :groups
        end
        .tap do |declarations|
          declarations.has_many(:users, resource: users_resource, writable: true, readable:)
          declarations.has_one(:smtp_updated_by, resource: users_resource, writable: true)
          declarations.has_many(:requesters, resource: users_resource)
        end
        .new(guardian: Guardian.new, edition:)
    end
    let(:status) { "400" }
    let(:pointer) { "/data/relationships/users/data" }

    shared_examples "invalid relationship input" do
      it "reports the invalid member", :aggregate_failures do
        expect(body).to be_invalid
        expect(body.refusals).to contain_exactly(have_attributes(status:, source: { pointer: }))
      end
    end

    it "preserves identifier strings for the service contract", :aggregate_failures do
      expect(body).not_to be_invalid
      expect(body.parameters).to eq(user_ids: ["0012"])
    end

    context "when a writable relationship is unreadable" do
      let(:readable) { ->(_guardian) { false } }

      it "accepts the supplied linkage", :aggregate_failures do
        expect(body).not_to be_invalid
        expect(body.parameters).to eq(user_ids: ["0012"])
      end
    end

    context "when relationships is an array" do
      let(:relationships) { [] }
      let(:pointer) { "/data/relationships" }

      it_behaves_like "invalid relationship input"
    end

    context "when a relationship is null" do
      let(:relationships) { { "users" => nil } }
      let(:pointer) { "/data/relationships/users" }

      it_behaves_like "invalid relationship input"
    end

    context "when a relationship omits data" do
      let(:relationships) { { "users" => { "meta" => {} } } }
      let(:pointer) { "/data/relationships/users" }

      it_behaves_like "invalid relationship input"
    end

    context "when to-many data is an object" do
      let(:relationships) { { "users" => { "data" => identifier } } }

      it_behaves_like "invalid relationship input"
    end

    context "when to-many data is null" do
      let(:relationships) { { "users" => { "data" => nil } } }

      it_behaves_like "invalid relationship input"
    end

    context "when to-one data is an array" do
      let(:relationships) { { "smtpUpdatedBy" => { "data" => [identifier] } } }
      let(:pointer) { "/data/relationships/smtpUpdatedBy/data" }

      it_behaves_like "invalid relationship input"
    end

    context "when an identifier is not an object" do
      let(:relationships) { { "users" => { "data" => [identifier, nil] } } }
      let(:pointer) { "/data/relationships/users/data/1" }

      it_behaves_like "invalid relationship input"
    end

    context "when an identifier omits its ID" do
      let(:identifier) { super().except("id") }
      let(:pointer) { "/data/relationships/users/data/0" }

      it_behaves_like "invalid relationship input"
    end

    context "when an identifier supplies a numeric ID" do
      let(:identifier) { super().merge("id" => 12) }
      let(:pointer) { "/data/relationships/users/data/0/id" }

      it_behaves_like "invalid relationship input"
    end

    context "when an identifier type is not a string" do
      let(:identifier) { super().merge("type" => ["users"]) }
      let(:pointer) { "/data/relationships/users/data/0/type" }

      it_behaves_like "invalid relationship input"
    end

    context "when a later identifier has the wrong type" do
      let(:relationships) do
        { "users" => { "data" => [identifier, identifier.merge("type" => "groups")] } }
      end
      let(:pointer) { "/data/relationships/users/data/1/type" }
      let(:status) { "409" }

      it_behaves_like "invalid relationship input"
    end

    context "when a relationship is read-only" do
      let(:relationships) { { "requesters" => { "data" => [identifier] } } }
      let(:pointer) { "/data/relationships/requesters" }
      let(:status) { "403" }

      it_behaves_like "invalid relationship input"
    end

    context "when a relationship is unknown" do
      let(:relationships) { { "reviewers" => { "data" => [identifier] } } }
      let(:pointer) { "/data/relationships/reviewers" }
      let(:status) { "403" }

      it_behaves_like "invalid relationship input"
    end

    context "when an attribute maps to the same parameter" do
      let(:attributes) { { "userIds" => [34] } }
      let(:pointer) { "/data/attributes/userIds" }

      it_behaves_like "invalid relationship input"

      context "when linkage is omitted" do
        let(:relationships) { {} }

        it_behaves_like "invalid relationship input"
      end
    end

    context "when an attribute names a to-one relationship parameter" do
      let(:attributes) { { "smtpUpdatedById" => 34 } }
      let(:pointer) { "/data/attributes/smtpUpdatedById" }

      it_behaves_like "invalid relationship input"
    end

    context "when the service rejects an indexed identifier" do
      subject(:validation_errors) { body.validation_errors(errors) }

      let(:relationships) { { "users" => { "data" => [identifier, identifier] } } }
      let(:errors) { Service::ContractBase.new.errors }
      let(:attribute) { :"user_ids[1]" }

      before { errors.add(attribute, "is invalid") }

      it "points to the submitted identifier" do
        expect(validation_errors.map(&:source)).to contain_exactly(
          pointer: "/data/relationships/users/data/1/id",
        )
      end

      context "when the error index has no submitted identifier" do
        let(:attribute) { :"user_ids[3]" }

        it "points to the submitted linkage" do
          expect(validation_errors.map(&:source)).to contain_exactly(
            pointer: "/data/relationships/users/data",
          )
        end
      end
    end

    context "when the service rejects an omitted relationship" do
      subject(:validation_errors) { body.validation_errors(errors) }

      let(:attributes) { { "name" => "A group" } }
      let(:relationships) { {} }
      let(:errors) { Service::ContractBase.new.errors }

      before { errors.add(:user_ids, "must be supplied") }

      it "points to the relationships object" do
        expect(validation_errors.map(&:source)).to contain_exactly(pointer: "/data/relationships")
      end

      context "when the relationships member is absent" do
        let(:document) { { "data" => { "type" => "groups", "attributes" => attributes } } }

        it "points to the resource object" do
          expect(validation_errors.map(&:source)).to contain_exactly(pointer: "/data")
        end
      end
    end

    context "when the model rejects an association" do
      subject(:validation_errors) { body.validation_errors(errors) }

      let(:attributes) { { "name" => "A group" } }
      let(:errors) { Group.new.errors }
      let(:attribute) { :users }

      before { errors.add(attribute, "is invalid") }

      it "points to the submitted relationship data" do
        expect(validation_errors.map(&:source)).to contain_exactly(
          pointer: "/data/relationships/users/data",
        )
      end

      context "when the association is to-one" do
        let(:attribute) { :smtp_updated_by }
        let(:relationships) { { "smtpUpdatedBy" => { "data" => identifier } } }

        it "points to the submitted relationship data" do
          expect(validation_errors.map(&:source)).to contain_exactly(
            pointer: "/data/relationships/smtpUpdatedBy/data",
          )
        end
      end

      context "when the error names an indexed association member" do
        let(:attribute) { :"users[1].username" }
        let(:relationships) { { "users" => { "data" => [identifier, identifier] } } }

        it "points to the submitted identifier" do
          expect(validation_errors.map(&:source)).to contain_exactly(
            pointer: "/data/relationships/users/data/1/id",
          )
        end
      end

      context "when the relationship is omitted" do
        let(:relationships) { {} }

        it "points to the relationships object" do
          expect(validation_errors.map(&:source)).to contain_exactly(pointer: "/data/relationships")
        end
      end

      context "when the client uses a historical relationship name" do
        let(:relationships) { { "members" => { "data" => [identifier] } } }
        let(:edition) do
          JsonApiKit::Edition.new(
            [
              Class
                .new(JsonApiKit::VersionChange) do
                  resource(:groups) { renamed_relationship from: :members, to: :users }
                end
                .new(__FILE__),
            ],
          )
        end

        it "points to the historical relationship data" do
          expect(validation_errors.map(&:source)).to contain_exactly(
            pointer: "/data/relationships/members/data",
          )
        end
      end
    end

    context "when an attribute names a read-only relationship parameter" do
      let(:attributes) { { "requesterIds" => [34] } }
      let(:pointer) { "/data/attributes/requesterIds" }

      it_behaves_like "invalid relationship input"
    end
  end

  describe "#invalid?" do
    context "when the type is an empty array" do
      let(:document) { { "data" => { "type" => [] } } }

      it { is_expected.to be_invalid }
    end

    context "when the type is an array containing the expected type" do
      let(:document) { { "data" => { "type" => ["topics"] } } }

      it { is_expected.to be_invalid }
    end
  end
end
