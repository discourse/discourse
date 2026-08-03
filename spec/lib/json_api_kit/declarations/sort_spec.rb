# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Sort do
  subject(:sort) { described_class.new(:created_at) }

  describe "#name" do
    subject(:name) { sort.name }

    it "returns the name a request sorts by" do
      expect(name).to eq("created_at")
    end
  end

  describe "#key" do
    subject(:key) { sort.key(schema: JsonApiKit::Schema.new(Topic), direction: :desc) }

    it "orders by the column of its own name" do
      expect(key.name).to eq(:created_at)
    end

    it "reads it in that direction" do
      expect(key.direction.to_sym).to eq(:desc)
    end

    context "when the column cannot be null" do
      it { is_expected.not_to be_nullable }
    end

    context "when the column can be null" do
      let(:sort) { described_class.new(:pinned_at) }

      it { is_expected.to be_nulls_trailing }
    end

    context "when the sort declares where its nulls go" do
      let(:sort) { described_class.new(:pinned_at, nulls: :first) }

      it { is_expected.to be_nulls_read_first }
    end

    context "when the sort declares another column" do
      let(:sort) { described_class.new(:ran_at, column: :last_posted_at) }

      it "orders by that column, not by its own name" do
        expect(key.name).to eq(:last_posted_at)
      end

      it "sends its nulls to the end, because that column can be null" do
        expect(key).to be_nulls_trailing
      end
    end

    context "when the sort declares the SQL behind it" do
      let(:sort) do
        described_class.new(
          :author,
          sql: "users.username",
          joins: "LEFT JOIN users ON users.id = topics.user_id",
        )
      end

      it "orders by that SQL" do
        expect(key.sql).to eq("users.username")
      end

      it "carries the joins that SQL needs" do
        expect(key.joins).to contain_exactly("LEFT JOIN users ON users.id = topics.user_id")
      end

      it "sends its nulls to the end, because it reads no column" do
        expect(key).to be_nulls_trailing
      end
    end

    context "when the name of the sort holds a dot" do
      let(:sort) { described_class.new("user.username", sql: "users.username") }

      it "replaces the dot with an underscore" do
        expect(key.name).to eq(:user_username)
      end
    end
  end
end
