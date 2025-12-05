# frozen_string_literal: true

RSpec.describe Service::ContractBase, type: :model do
  subject(:contract) { contract_class.new(params) }

  describe "Nested attributes" do
    let(:contract_class) do
      Class.new(described_class) do
        def self.name = "TestContract"

        attribute :channel_id, :integer

        attribute :record do
          attribute :id, :integer
          attribute :created_at, :datetime
          attribute :enabled, :boolean
        end

        attribute :user do
          attribute :username, :string
          attribute :age, :integer

          validates :username, presence: true
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
            expect(contract.errors[:user]).to be_present
          end
        end
      end
    end

    it "casts nested attributes to contract objects" do
      expect(contract).to have_attributes(
        record: a_kind_of(Service::ContractBase),
        user: a_kind_of(Service::ContractBase),
      )
    end

    it "exposes nested attribute values" do
      expect(contract).to have_attributes(
        record: an_object_having_attributes(id: 1, enabled: true, created_at:),
        user: an_object_having_attributes(username: "alice", age: 30),
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
      )
    end

    context "with multiple levels of nesting" do
      let(:contract_class) do
        Class.new(described_class) do
          attribute :data do
            attribute :nested do
              attribute :value, :string
            end
          end
        end
      end

      let(:params) { { data: { nested: { value: "deep" } } } }

      it { is_expected.to be_valid }

      it "handles deeply nested structures" do
        expect(contract.data.nested.value).to eq("deep")
      end

      it "properly converts to a hash" do
        expect(contract.to_hash).to include(data: { nested: { value: "deep" } })
      end
    end
  end
end
