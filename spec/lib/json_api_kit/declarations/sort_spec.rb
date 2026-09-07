# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Sort do
  subject(:sort) { described_class.for(:created_at) }

  describe "#name" do
    subject(:name) { sort.name }

    it { is_expected.to eq("created_at") }
  end

  describe "#key" do
    subject(:key) { sort.key(schema: JsonApiKit::Schema.new(Topic), direction: :desc) }

    it "orders by the column of the same name" do
      expect(key.name).to eq(:created_at)
    end

    it "orders in that direction" do
      expect(key.direction.to_sym).to eq(:desc)
    end

    context "when the column cannot be null" do
      it { is_expected.not_to be_nullable }
    end

    context "when the column can be null" do
      let(:sort) { described_class.for(:pinned_at) }

      it { is_expected.to be_nulls_trailing }
    end

    context "with nulls: :first" do
      let(:sort) { described_class.for(:pinned_at, nulls: :first) }

      it { is_expected.to be_nulls_read_first }
    end

    context "with column" do
      let(:sort) { described_class.for(:ran_at, column: :last_posted_at) }

      it "orders by that column" do
        expect(key.name).to eq(:last_posted_at)
      end

      it { is_expected.to be_nulls_trailing }
    end

    context "with sql" do
      let(:sort) do
        described_class.for(
          :author,
          sql: "users.username",
          joins: "LEFT JOIN users ON users.id = topics.user_id",
        )
      end

      it "orders by that SQL" do
        expect(key.sql).to eq("users.username")
      end

      it "carries those joins" do
        expect(key.joins).to eq(
          JsonApiKit::Joins.for("LEFT JOIN users ON users.id = topics.user_id"),
        )
      end

      it { is_expected.to be_nulls_trailing }
    end

    context "when sort is a relationship" do
      let(:sort) { described_class.for("user.username") }

      it "orders by the related column" do
        expect(key.sql).to eq("users.username")
      end

      it "joins the association" do
        expect(key.joins).to eq(JsonApiKit::Joins.for(:user))
      end

      it "names the key with an underscore" do
        expect(key.name).to eq(:user_username)
      end

      it { is_expected.to be_nulls_trailing }

      context "when the model has a column of that name" do
        subject(:key) { sort.key(schema: JsonApiKit::Schema.new(Post), direction: :desc) }

        let(:sort) { described_class.for("topic.id") }

        it { is_expected.to be_nulls_trailing }
      end

      context "with sql" do
        let(:sort) { described_class.for("user.username", sql: "lower(users.username)") }

        it "orders by that SQL and still joins the association" do
          expect(key.sql).to eq("lower(users.username)")
          expect(key.joins).to eq(JsonApiKit::Joins.for(:user))
        end
      end

      context "with joins" do
        let(:sort) do
          described_class.for(
            "user.username",
            joins: "LEFT JOIN users ON users.id = topics.user_id",
          )
        end

        it "uses those joins and still reads the related column" do
          expect(key.sql).to eq("users.username")
          expect(key.joins).to eq(
            JsonApiKit::Joins.for("LEFT JOIN users ON users.id = topics.user_id"),
          )
        end
      end

      context "with nulls: :first" do
        let(:sort) { described_class.for("user.username", nulls: :first) }

        it { is_expected.to be_nulls_read_first }
      end

      context "when the association doesn’t exist" do
        let(:sort) { described_class.for("author.username") }

        it { expect { key }.to raise_error(JsonApiKit::Schema::MissingAssociation, /author/) }
      end
    end
  end
end
