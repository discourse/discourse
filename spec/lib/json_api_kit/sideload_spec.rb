# frozen_string_literal: true

RSpec.describe JsonApiKit::Sideload do
  subject(:sideload) { described_class.new(relationship, paths:, rows:, request:, schema:) }

  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author, title: "A topic read with its author") }

  let(:users_resource) do
    Class.new(JsonApiKit::Resource) do
      model User
      type :users
      attribute :username
    end
  end
  let(:relationship) do
    JsonApiKit::Declarations::Relationship::ToOne.new(:user, resource: users_resource)
  end
  let(:paths) { JsonApiKit::Paths.new([]) }
  let(:records) { [topic] }
  let(:rows) { records.map { JsonApiKit::Pagination::Row.new(record: it, segment: nil) } }
  let(:params) { {} }
  let(:request) { JsonApiKit::Request::Collection.new(params, guardian: Guardian.new) }
  let(:schema) { JsonApiKit::Schema.new(Topic) }

  describe "#linkage_for" do
    subject(:linkage) { sideload.linkage_for(rows.first) }

    it "holds the record that the row relates to" do
      expect(linkage.records.map(&:record)).to eq([author])
    end

    it "holds it under the linkage that the relationship declares" do
      expect(linkage).to be_a(JsonApiKit::Linkage::ToOne)
    end

    context "when the row relates to nothing" do
      fab!(:without_category) { Fabricate(:private_message_topic, title: "A topic in no category") }

      let(:categories_resource) do
        Class.new(JsonApiKit::Resource) do
          model Category
          type :categories
        end
      end
      let(:relationship) do
        JsonApiKit::Declarations::Relationship::ToOne.new(:category, resource: categories_resource)
      end
      let(:records) { [without_category] }

      it "holds no record" do
        expect(linkage.records).to be_empty
      end
    end

    context "when a path reads past the relationship" do
      let(:paths) { JsonApiKit::Paths.new(%w[user.groups]).next_for("user") }

      before { allow(relationship).to receive(:listing).and_call_original }

      it "gives the rest of the path to the related resource" do
        linkage
        expect(relationship).to have_received(:listing).with(
          a_hash_including(include: paths),
          any_args,
        )
      end
    end

    context "when a request asks for fields of the related type" do
      let(:params) { { fields: { users: %w[username] } } }

      it "renders the related record as those fields" do
        expect(linkage.records.map(&:attributes)).to eq([{ "username" => author.username }])
      end
    end

    context "when the page holds several rows" do
      fab!(:another) { Fabricate(:topic, user: author, title: "Another topic by that author") }

      let(:records) { [topic, another] }
      let(:reads_of_users) do
        track_sql_queries { rows.each { sideload.linkage_for(it) } }.grep(/FROM "users"/).size
      end

      def related_record(row) = sideload.linkage_for(row).records.first

      it "reads the related rows of them all in one query" do
        expect(reads_of_users).to eq(1)
      end

      it "gives two rows that relate to one row the same record" do
        expect(related_record(rows.first)).to be(related_record(rows.last))
      end
    end
  end
end
