# frozen_string_literal: true

RSpec.describe Service::ContractBase, type: :model do
  subject(:contract) { contract_class.new(params) }

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
