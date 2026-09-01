# frozen_string_literal: true

RSpec.describe JsonApiKit::Association do
  subject(:association) { JsonApiKit::Schema.new(Topic).association(name, owner_rows) }

  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author, title: "A topic that relates to rows") }

  let(:name) { :user }
  let(:owner_rows) { [topic] }

  describe "#related_scope" do
    it "returns the rows those rows reach" do
      expect(association.related_scope).to eq([author])
    end

    context "when the page holds no row" do
      let(:owner_rows) { [] }

      it "returns none" do
        expect(association.related_scope).to be_empty
      end
    end

    context "when the key is on the related row" do
      let(:name) { :posts }

      fab!(:post) { Fabricate(:post, topic:) }

      it "returns the rows those rows reach" do
        expect(association.related_scope).to eq([post])
      end
    end

    context "when the relationship narrows the rows itself" do
      let(:name) { :first_post }

      fab!(:first) { Fabricate(:post, topic:) }
      fab!(:second) { Fabricate(:post, topic:) }

      it "returns only the rows it allows" do
        expect(association.related_scope).to eq([first])
      end
    end

    context "when the relationship goes through another table" do
      let(:name) { :tags }

      fab!(:tag) { Fabricate(:tag, name: "a-tag-reached-through") }
      fab!(:tagging) { Fabricate(:topic_tag, topic:, tag:) }

      it "returns the rows those rows reach" do
        expect(association.related_scope).to eq([tag])
      end
    end
  end

  describe "#pair" do
    it "returns what each row relates to" do
      expect(association.pair([author])).to eq(topic => [author])
    end

    it "returns nothing for a row that reaches none of them" do
      expect(association.pair([])).to eq(topic => [])
    end

    context "when several rows reach the same one" do
      fab!(:another) { Fabricate(:topic, user: author, title: "Another topic by that author") }

      let(:owner_rows) { [topic, another] }

      it "returns it for each of them" do
        expect(association.pair([author])).to eq(topic => [author], another => [author])
      end
    end

    context "when the key is on the related row" do
      let(:name) { :posts }

      fab!(:post) { Fabricate(:post, topic:) }
      fab!(:elsewhere, :post)

      it "returns only the rows that name it" do
        expect(association.pair([post, elsewhere])).to eq(topic => [post])
      end
    end

    context "when the relationship goes through another table" do
      let(:name) { :tags }

      fab!(:tag) { Fabricate(:tag, name: "a-tag-reached-through") }
      fab!(:unrelated_tag) { Fabricate(:tag, name: "a-tag-nothing-carries") }
      fab!(:tagging) { Fabricate(:topic_tag, topic:, tag:) }

      it "returns only the rows the other table pairs it with" do
        expect(association.pair([tag, unrelated_tag])).to eq(topic => [tag])
      end
    end

    context "when a row relates to several rows" do
      let(:name) { :tags }

      fab!(:read_first) { Fabricate(:tag, name: "the-tag-read-first") }
      fab!(:read_second) { Fabricate(:tag, name: "the-tag-read-second") }
      fab!(:paired_first) { Fabricate(:topic_tag, topic:, tag: read_second) }
      fab!(:paired_second) { Fabricate(:topic_tag, topic:, tag: read_first) }

      it "returns them in the order the related resource read them" do
        expect(association.pair([read_first, read_second])).to eq(
          topic => [read_first, read_second],
        )
      end
    end
  end
end
