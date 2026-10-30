# frozen_string_literal: true

RSpec.describe Service::ContractBase, type: :model do
  subject(:contract) { contract_class.new(params) }

  describe "#provided?" do
    subject(:contract) { contract_class.new(**params) }

    let(:contract_class) do
      Class.new(described_class) do
        attribute :user_id, :integer
        attribute :group_ids, :array
        attribute :enabled, :boolean, default: true
        attribute :settings
      end
    end
    let(:params) { { user_id: "3" } }

    it "recognizes a supplied attribute", :aggregate_failures do
      expect(contract).to be_provided(:user_id)
      expect(contract).to be_provided("user_id")
    end

    context "when the attribute is omitted" do
      let(:params) { {} }

      it "reports the attribute as omitted" do
        expect(contract).not_to be_provided(:user_id)
      end

      it "does not treat a declaration default as supplied" do
        expect(contract).not_to be_provided(:enabled)
      end
    end

    context "when the supplied value is nil" do
      let(:params) { { user_id: nil } }

      it { is_expected.to be_provided(:user_id) }
    end

    context "when the supplied value is false" do
      let(:params) { { enabled: false } }

      it { is_expected.to be_provided(:enabled) }
    end

    context "when the supplied value is an empty array" do
      let(:params) { { group_ids: [] } }

      it { is_expected.to be_provided(:group_ids) }
    end

    context "when the supplied value is an empty hash" do
      let(:params) { { settings: {} } }

      it { is_expected.to be_provided(:settings) }
    end

    context "when coercion produces nil" do
      let(:params) { { user_id: "" } }

      it "retains the supplied attribute's presence", :aggregate_failures do
        expect(contract.user_id).to be_nil
        expect(contract).to be_provided(:user_id)
      end
    end

    context "when the input has string keys" do
      let(:params) { super().stringify_keys }

      it { is_expected.to be_provided(:user_id) }
    end

    context "when a positional hash supplies the input" do
      subject(:contract) { contract_class.new(params) }

      it { is_expected.to be_provided(:user_id) }
    end

    context "when the supplied attribute is undeclared" do
      let(:params) { super().merge(unknown: "ignored") }

      it "excludes the undeclared attribute" do
        expect(contract).not_to be_provided(:unknown)
      end
    end

    context "when the contract later assigns an omitted attribute" do
      before { contract.enabled = false }

      it "preserves the original omission" do
        expect(contract).not_to be_provided(:enabled)
      end
    end
  end

  describe "Nested attributes" do
    let(:contract_class) do
      Class.new(described_class) do
        def self.name = "TestContract"

        attribute :channel_id, :integer

        attribute :record, :hash do
          attribute :id, :integer
          attribute :created_at, :datetime
          attribute :enabled, :boolean
        end

        attribute :user do # without an explicit type, it defaults to :hash
          attribute :username, :string
          attribute :age, :integer

          validates :username, presence: true
        end

        attribute :records, :array do
          attribute :name

          validates :name, presence: true
        end

        validates :channel_id, :user, presence: true
      end
    end
    let(:params) do
      {
        channel_id: 123,
        record: {
          id: 1,
          created_at: "2025-12-25 00:00",
          enabled: true,
        },
        user: {
          username: "alice",
          age: 30,
        },
        records: [{ name: "first" }, { name: "second" }],
      }
    end
    let(:created_at) { Time.zone.parse("2025-12-25 00:00") }

    context "when nested input contains an undeclared metadata name" do
      let(:params) { super().deep_merge(user: { provided_attributes: "unexpected" }) }

      it "accepts the declared attributes" do
        expect(contract).to be_valid
      end
    end

    context "when nested containers are frozen" do
      subject(:contract) { contract_class.new(**params) }

      let(:params) { super().deep_stringify_keys }

      before do
        params["record"].freeze
        params["user"].freeze
        params["records"].each(&:freeze)
        params["records"].freeze
        params.freeze
      end

      it "accepts the parameters" do
        expect(contract).to be_valid
      end
    end

    describe "Validations" do
      it { is_expected.to validate_presence_of(:channel_id) }
      it { is_expected.to validate_presence_of(:user) }

      context "when user is defined" do
        subject(:user_contract) { contract.user }

        it { is_expected.to validate_presence_of(:username) }

        context "when user has errors" do
          before { params[:user].delete(:username) }

          it "marks the main contract as invalid" do
            expect(contract).to be_invalid
            expect(contract.errors).to include(:"user.username")
          end
        end
      end

      context "when records is defined" do
        subject(:records_contracts) { contract.records }

        it { is_expected.to all validate_presence_of(:name) }

        context "when records has errors" do
          before { params[:records][1].delete(:name) }

          it "marks the main contract as invalid" do
            expect(contract).to be_invalid
            expect(contract.errors).to include(:"records[1].name")
          end
        end
      end
    end

    context "when the main contract has options" do
      subject(:contract) { contract_class.new(params, options: { locale: "fr" }) }

      it "provides them to a nested contract" do
        contract.valid?
        expect(contract.record.options).to include(locale: "fr")
      end

      it "provides them to a contract nested inside a nested one" do
        contract.valid?
        expect(contract.records.map(&:options)).to all(include(locale: "fr"))
      end
    end

    it "casts nested attributes to contract objects" do
      expect(contract).to have_attributes(
        record: a_kind_of(Service::ContractBase),
        user: a_kind_of(Service::ContractBase),
        records: all(a_kind_of(Service::ContractBase)),
      )
    end

    it "exposes nested attribute values" do
      expect(contract).to have_attributes(
        record: an_object_having_attributes(id: 1, enabled: true, created_at:),
        user: an_object_having_attributes(username: "alice", age: 30),
        records:
          a_collection_containing_exactly(
            an_object_having_attributes(name: "first"),
            an_object_having_attributes(name: "second"),
          ),
      )
    end

    it "converts to a nested hash" do
      expect(contract.to_hash).to include(
        channel_id: 123,
        record: {
          id: 1,
          enabled: true,
          created_at:,
        },
        user: {
          username: "alice",
          age: 30,
        },
        records: [{ name: "first" }, { name: "second" }],
      )
    end

    context "with multiple levels of nesting" do
      let(:contract_class) do
        Class.new(described_class) do
          def self.name = "TestContract"

          attribute :data do
            attribute :nested do
              attribute :value, :string

              validates :value, presence: true
            end
          end

          attribute :items, :array do
            attribute :name, :string

            attribute :nested, :array do
              attribute :value, :string

              validates :value, presence: true
            end

            validates :name, presence: true
          end
        end
      end
      let(:params) do
        {
          data: {
            nested: {
              value: "deep",
            },
          },
          items: [{ name: "item 1", nested: [{ value: "deep" }] }],
        }
      end

      it { is_expected.to be_valid }

      it "handles deeply nested structures" do
        expect(contract.data.nested.value).to eq("deep")
        expect(contract.items[0].nested[0].value).to eq("deep")
      end

      it "properly converts to a hash" do
        expect(contract.to_hash).to include(
          data: {
            nested: {
              value: "deep",
            },
          },
          items: [{ name: "item 1", nested: [{ value: "deep" }] }],
        )
      end

      context "when there are errors at several levels" do
        let(:params) do
          {
            data: {
              nested: {
                value: "deep",
              },
            },
            items: [
              { name: "item 1", nested: [{ value: "" }] },
              { nested: [{ value: "1" }, { value: "" }] },
            ],
          }
        end

        it "reports all the proper errors" do
          expect(contract).to be_invalid
          expect(contract.errors).to include(
            :"items[0].nested[0].value",
            :"items[1].name",
            :"items[1].nested[1].value",
          )
        end
      end
    end
  end
end
