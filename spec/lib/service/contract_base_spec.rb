# frozen_string_literal: true

RSpec.describe Service::ContractBase do
  describe "nested attributes" do
    subject(:contract) { contract_class.new(**params) }

    let(:contract_class) do
      Class.new(described_class) do
        attribute :channel_id, :integer

        attribute :record do
          attribute :id, :integer
          attribute :created_at, :datetime
          attribute :enabled, :boolean
        end

        attribute :user do
          attribute :username, :string
          attribute :age, :integer
        end

        validates :channel_id, presence: true
      end
    end

    context "when all parameters are valid" do
      let(:params) do
        {
          channel_id: 123,
          record: {
            id: 1,
            created_at: Time.zone.now,
            enabled: true,
          },
          user: {
            username: "alice",
            age: 30,
          },
        }
      end

      it { is_expected.to be_valid }

      it "casts nested attributes to contract objects" do
        expect(contract.record).to be_a(Service::ContractBase)
        expect(contract.user).to be_a(Service::ContractBase)
      end

      it "exposes nested attribute values" do
        expect(contract.record.id).to eq(1)
        expect(contract.record.enabled).to eq(true)
        expect(contract.user.username).to eq("alice")
        expect(contract.user.age).to eq(30)
      end

      it "converts to nested hash" do
        hash = contract.to_hash
        expect(hash[:channel_id]).to eq(123)
        expect(hash[:record]).to be_a(Hash)
        expect(hash[:record][:id]).to eq(1)
        expect(hash[:record][:enabled]).to eq(true)
        expect(hash[:user]).to be_a(Hash)
        expect(hash[:user][:username]).to eq("alice")
      end
    end

    context "when nested attributes are nil" do
      let(:params) { { channel_id: 123, record: nil, user: nil } }

      it { is_expected.to be_valid }

      it "returns nil for nil nested attributes" do
        expect(contract.record).to be_nil
        expect(contract.user).to be_nil
      end
    end

    context "when top-level validation fails" do
      let(:params) { { channel_id: nil, record: { id: 1 }, user: { username: "alice" } } }

      it { is_expected.not_to be_valid }
    end

    context "when nested validation fails" do
      let(:contract_class) { TestContractWithValidation }

      # Use a named class to avoid issues with ActiveModel requiring model names
      before do
        class TestContractWithValidation < Service::ContractBase
          attribute :channel_id, :integer

          attribute :user do
            attribute :username, :string
            attribute :age, :integer

            validates :username, presence: true
            validates :age, numericality: { greater_than: 0 }
          end

          validates :channel_id, presence: true
        end
      end

      after { Object.send(:remove_const, :TestContractWithValidation) }

      context "with missing required nested field" do
        let(:params) { { channel_id: 123, user: { username: nil, age: 25 } } }

        it { is_expected.not_to be_valid }

        it "marks the nested attribute as invalid" do
          contract.valid?
          expect(contract.errors[:user]).to be_present
        end

        it "nested contract has its own errors" do
          contract.valid?
          expect(contract.user.errors[:username]).to be_present
        end
      end

      context "with invalid nested field value" do
        let(:params) { { channel_id: 123, user: { username: "alice", age: -5 } } }

        it { is_expected.not_to be_valid }

        it "marks the nested attribute as invalid" do
          contract.valid?
          expect(contract.errors[:user]).to be_present
        end

        it "nested contract has its own errors" do
          contract.valid?
          expect(contract.user.errors[:age]).to be_present
        end
      end
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
        expect(contract.data).to be_a(Service::ContractBase)
        expect(contract.data.nested).to be_a(Service::ContractBase)
        expect(contract.data.nested.value).to eq("deep")
      end

      it "converts deeply nested structures to hash" do
        hash = contract.to_hash
        expect(hash[:data]).to be_a(Hash)
        expect(hash[:data][:nested]).to be_a(Hash)
        expect(hash[:data][:nested][:value]).to eq("deep")
      end
    end

    context "with string keys in input" do
      let(:params) { { "channel_id" => 123, "user" => { "username" => "bob", "age" => 40 } } }

      it "handles string keys correctly" do
        expect(contract).to be_valid
        expect(contract.user.username).to eq("bob")
      end
    end

    context "with type coercion in nested attributes" do
      let(:params) { { channel_id: 123, record: { id: "42", enabled: "true" } } }

      it "coerces nested attribute types" do
        expect(contract.record.id).to eq(42)
        expect(contract.record.enabled).to eq(true)
      end
    end
  end

  describe "flat attributes" do
    subject(:contract) { contract_class.new(**params) }

    let(:contract_class) do
      Class.new(described_class) do
        attribute :name, :string
        attribute :count, :integer
        attribute :active, :boolean

        validates :name, presence: true
      end
    end

    context "when parameters are valid" do
      let(:params) { { name: "test", count: 5, active: true } }

      it { is_expected.to be_valid }

      it "converts to hash" do
        expect(contract.to_hash).to eq({ name: "test", count: 5, active: true })
      end
    end

    context "when validation fails" do
      let(:params) { { name: nil, count: 5 } }

      it { is_expected.not_to be_valid }
    end
  end
end
