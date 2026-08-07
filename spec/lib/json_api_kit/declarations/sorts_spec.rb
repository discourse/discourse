# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Sorts do
  subject(:sorts) { described_class.new(declared, model: Topic, default:, unique_by:) }

  let(:sort) { JsonApiKit::Declarations::Sort }
  let(:declared) { [sort.new(:created_at), sort.new(:ran_at, column: :last_posted_at)] }
  let(:default) { {} }
  let(:unique_by) { [] }

  describe "#fetch" do
    subject(:fetched) { sorts.fetch("created_at") }

    it "is the sort a client names" do
      expect(fetched.name).to eq("created_at")
    end

    context "with a name the resource declared no sort for" do
      subject(:fetched) { sorts.fetch("secrets") }

      it "refuses it, a client asking for an order nothing offers" do
        expect { fetched }.to raise_error(described_class::Unsupported, /secrets/)
      end
    end
  end

  describe "#keyset" do
    subject(:keyset) { sorts.keyset(ordering) }

    let(:ordering) { { created_at: :desc } }

    it "orders by the sort the request names" do
      expect(keyset.leading.name).to eq(:created_at)
    end

    it "reads it the way the request asked for" do
      expect(keyset.leading.direction.to_sym).to eq(:desc)
    end

    it "breaks its ties by the model's own key, no order being reliable that rows can share" do
      expect(keyset.keys.last.name).to eq(:id)
    end

    it "reads that key the way the order's leading key reads, one index serving both" do
      expect(keyset.keys.last.direction.to_sym).to eq(:desc)
    end

    context "with several sorts named" do
      let(:ordering) { { ran_at: :asc, created_at: :desc } }

      it "orders by each in the sequence the request names them" do
        expect(keyset.keys.map(&:name)).to eq(%i[last_posted_at created_at id])
      end
    end

    context "with a sort the resource never declared" do
      let(:ordering) { { secrets: :desc } }

      it "refuses the order rather than reading one nobody offered" do
        expect { keyset }.to raise_error(described_class::Unsupported)
      end
    end

    context "when the resource's own order names a sort it never declared" do
      let(:ordering) { {} }
      let(:default) { { secrets: :desc } }

      it "refuses it, a default being a sort like any other" do
        expect { keyset }.to raise_error(described_class::Unsupported)
      end
    end

    context "when the request names no sort" do
      let(:ordering) { {} }
      let(:default) { { ran_at: :desc } }

      it "orders by what the resource orders by" do
        expect(keyset.keys.map(&:name)).to eq(%i[last_posted_at id])
      end
    end

    context "when neither the request nor the resource names one" do
      let(:ordering) { {} }

      it "orders by the key that makes it unique, upwards" do
        expect(keyset.keys.map { [it.name, it.direction.to_sym] }).to eq([%i[id asc]])
      end
    end

    context "with a unique key of its own declared" do
      let(:unique_by) { %i[title id] }

      it "breaks ties by every column of it, in the sequence declared" do
        expect(keyset.keys.map(&:name)).to eq(%i[created_at title id])
      end
    end

    context "when the request names the key ties are broken by" do
      let(:ordering) { { created_at: :desc, id: :asc } }
      let(:declared) { [sort.new(:created_at), sort.new(:id)] }

      it "keeps the direction the client asked for, reading it once" do
        expect(keyset.keys.map { [it.name, it.direction.to_sym] }).to eq(
          [%i[created_at desc], %i[id asc]],
        )
      end
    end
  end
end
