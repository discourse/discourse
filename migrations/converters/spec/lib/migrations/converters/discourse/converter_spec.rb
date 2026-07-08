# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::Converter do
  describe "#step_args" do
    it "builds a fresh source adapter per step so concurrent steps don't share a connection" do
      adapters = [
        instance_double(Migrations::Converters::Adapter::Postgres),
        instance_double(Migrations::Converters::Adapter::Postgres),
      ]
      allow(Migrations::Converters::Adapter::Postgres).to receive(:new).and_return(*adapters)

      converter = described_class.new(source_db: { host: "localhost" })

      first = converter.step_args(:first_step)[:source_db]
      second = converter.step_args(:second_step)[:source_db]

      expect(first).to be(adapters[0])
      expect(second).to be(adapters[1])
      expect(Migrations::Converters::Adapter::Postgres).to have_received(:new).with(
        { host: "localhost" },
      ).twice
    end

    context "for the Posts step" do
      let(:source_db) { instance_double(Migrations::Converters::Adapter::Postgres) }

      before do
        allow(Migrations::Converters::Adapter::Postgres).to receive(:new).and_return(source_db)
        allow(source_db).to receive(:query).with("SELECT username FROM users").and_return([])
        allow(source_db).to receive(:query).with("SELECT name FROM groups").and_return([])
        allow(source_db).to receive(:query).with("SELECT name FROM custom_emojis").and_return([])
        allow(source_db).to receive(:query).with("SELECT name FROM tags").and_return([])
        allow(source_db).to receive(:query).with(a_string_including("FROM categories")).and_return(
          [],
        )
        allow(source_db).to receive(:query_value).and_return(nil)
      end

      it "loads the source group names and here_mention setting for mention classification" do
        allow(source_db).to receive(:query).with("SELECT name FROM groups").and_return(
          [{ name: "staff" }, { name: "moderators" }],
        )
        allow(source_db).to receive(:query_value).and_return("everyone")

        args = described_class.new({}).step_args(Migrations::Converters::Discourse::Posts)

        expect(args[:source_db]).to be(source_db)
        expect(args[:group_names]).to eq(%w[staff moderators])
        expect(args[:here_mention]).to eq("everyone")
      end

      it "falls back to the default here_mention when the source has no such setting" do
        args = described_class.new({}).step_args(Migrations::Converters::Discourse::Posts)

        expect(args[:group_names]).to eq([])
        expect(args[:here_mention]).to eq("here")
      end

      it "builds the mention gate from usernames, group names, here_mention and all" do
        allow(source_db).to receive(:query).with("SELECT username FROM users").and_return(
          [{ username: "alice" }, { username: "Bob" }],
        )
        allow(source_db).to receive(:query).with("SELECT name FROM groups").and_return(
          [{ name: "Staff" }],
        )
        allow(source_db).to receive(:query_value).and_return("everyone")

        args = described_class.new({}).step_args(Migrations::Converters::Discourse::Posts)
        gate = args[:mention_names]

        expect(gate).to be_a(Migrations::SortedStringSet)
        expect(gate.include?("alice")).to be true
        expect(gate.include?("bob")).to be true
        expect(gate.include?("staff")).to be true
        expect(gate.include?("everyone")).to be true
        expect(gate.include?("all")).to be true
        expect(gate.include?("nobody")).to be false
      end

      it "loads normalized category slug paths and tag names for the hashtag gate" do
        allow(source_db).to receive(:query).with(a_string_including("FROM categories")).and_return(
          [{ slug: "Support", parent_slug: nil }, { slug: "Billing", parent_slug: "Support" }],
        )
        allow(source_db).to receive(:query).with("SELECT name FROM tags").and_return(
          [{ name: "Release" }],
        )

        args = described_class.new({}).step_args(Migrations::Converters::Discourse::Posts)
        gate = args[:hashtag_names]

        expect(gate).to be_a(Migrations::SortedStringSet)
        expect(gate.size).to eq(4)
        expect(gate.include?("support")).to be true
        expect(gate.include?("billing")).to be true
        expect(gate.include?("support:billing")).to be true
        expect(gate.include?("release")).to be true
      end

      it "loads the source custom emoji names for emoji extraction" do
        allow(source_db).to receive(:query).with("SELECT name FROM custom_emojis").and_return(
          [{ name: "parrot" }, { name: "+1" }],
        )

        args = described_class.new({}).step_args(Migrations::Converters::Discourse::Posts)

        expect(args[:custom_emoji_names]).to eq(%w[parrot +1])
      end
    end
  end
end
