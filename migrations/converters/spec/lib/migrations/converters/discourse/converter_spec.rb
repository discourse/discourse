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
        allow(source_db).to receive(:close)
        allow(source_db).to receive(:query).with("SELECT username FROM users").and_return([])
        allow(source_db).to receive(:query).with("SELECT name FROM groups").and_return([])
        allow(source_db).to receive(:query).with("SELECT name FROM custom_emojis").and_return([])
        allow(source_db).to receive(:query).with("SELECT name FROM tags").and_return([])
        allow(source_db).to receive(:query).with(
          "SELECT name, value FROM site_settings",
        ).and_return([])
        allow(source_db).to receive(:query).with(a_string_including("FROM categories")).and_return(
          [],
        )

        # The bundle is a build artifact, not something this spec is about, and
        # the suite already keeps one warm.
        allow(Migrations::Converters::MarkdownEngine::Bundle).to receive(:load_or_build).and_return(
          MarkdownEngineHelper.bundle,
        )
      end

      def posts_args(settings = {})
        described_class.new(settings).step_args(Migrations::Converters::Discourse::Posts)
      end

      it "loads the source group names and here_mention setting for mention classification" do
        allow(source_db).to receive(:query).with("SELECT name FROM groups").and_return(
          [{ name: "staff" }, { name: "moderators" }],
        )
        allow(source_db).to receive(:query).with(
          "SELECT name, value FROM site_settings",
        ).and_return([{ name: "here_mention", value: "everyone" }])

        args = posts_args

        expect(args[:source_db]).to be(source_db)
        expect(args[:group_names]).to eq(%w[staff moderators])
        expect(args[:here_mention]).to eq("everyone")
      end

      it "falls back to the default here_mention when the source has no such setting" do
        args = posts_args

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
        allow(source_db).to receive(:query).with(
          "SELECT name, value FROM site_settings",
        ).and_return([{ name: "here_mention", value: "everyone" }])

        gate = posts_args[:mention_names]

        expect(gate).to be_a(Migrations::CompactStringSet)
        expect(gate.include?("alice")).to be true
        expect(gate.include?("bob")).to be true
        expect(gate.include?("staff")).to be true
        expect(gate.include?("everyone")).to be true
        expect(gate.include?("all")).to be true
        expect(gate.include?("nobody")).to be false
      end

      it "gives the hashtag gate and the engine the same category slugs and tag names" do
        allow(source_db).to receive(:query).with(a_string_including("FROM categories")).and_return(
          [{ slug: "Support", parent_slug: nil }, { slug: "Billing", parent_slug: "Support" }],
        )
        allow(source_db).to receive(:query).with("SELECT name FROM tags").and_return(
          [{ name: "Release" }],
        )

        args = posts_args
        gate = args[:hashtag_names]

        expect(gate).to be_a(Migrations::CompactStringSet)
        expect(gate.size).to eq(4)
        expect(gate.include?("support")).to be true
        expect(gate.include?("billing")).to be true
        expect(gate.include?("support:billing")).to be true
        expect(gate.include?("release")).to be true

        expect(args[:markdown_config].category_lookup_slugs).to contain_exactly(
          "support",
          "billing",
        )
        expect(args[:markdown_config].tag_names).to eq(%w[release])
      end

      it "gives the engine the source's markdown site settings" do
        allow(source_db).to receive(:query).with(
          "SELECT name, value FROM site_settings",
        ).and_return(
          [
            { name: "enable_markdown_typographer", value: "f" },
            { name: "title", value: "not a markdown setting" },
          ],
        )

        settings = posts_args[:markdown_config].settings

        expect(settings["enable_markdown_typographer"]).to be false
        expect(settings).not_to have_key("title")
      end

      it "loads the source custom emoji names for emoji extraction" do
        allow(source_db).to receive(:query).with("SELECT name FROM custom_emojis").and_return(
          [{ name: "parrot" }, { name: "+1" }],
        )

        expect(posts_args[:custom_emoji_names]).to eq(%w[parrot +1])
      end

      it "loads the metadata once for the whole run" do
        converter = described_class.new({})

        first = converter.step_args(Migrations::Converters::Discourse::Posts)
        second = converter.step_args(Migrations::Converters::Discourse::Posts)

        expect(first[:markdown_bundle]).to be(second[:markdown_bundle])
        expect(first[:mention_names]).to be(second[:mention_names])
        expect(source_db).to have_received(:query).with("SELECT username FROM users").once
        expect(Migrations::Converters::MarkdownEngine::Bundle).to have_received(:load_or_build).once
      end

      # The scheduler plans a step on one thread while its coordinator builds it
      # on another, so both ask for the args at once.
      it "loads the metadata once when two threads ask at the same time" do
        converter = described_class.new({})
        bundles =
          Array
            .new(2) do
              Thread.new do
                converter.step_args(Migrations::Converters::Discourse::Posts)[:markdown_bundle]
              end
            end
            .map(&:value)

        expect(bundles.uniq.size).to eq(1)
        expect(source_db).to have_received(:query).with("SELECT username FROM users").once
      end

      it "closes the connection it opened for the metadata and hands the step a fresh one" do
        metadata_db = instance_double(Migrations::Converters::Adapter::Postgres)
        step_db = instance_double(Migrations::Converters::Adapter::Postgres)
        allow(Migrations::Converters::Adapter::Postgres).to receive(:new).and_return(
          step_db,
          metadata_db,
        )
        allow(metadata_db).to receive(:close)
        allow(metadata_db).to receive(:query).and_return([])

        args = posts_args

        expect(args[:source_db]).to be(step_db)
        expect(metadata_db).to have_received(:close)
      end

      it "maps each source host to its path prefix (base URL and former domains)" do
        args =
          posts_args(
            source_site: {
              base_url: "https://forum.example.com/forum",
              former_domains: %w[http://old.example.com older.example.com],
            },
          )

        expect(args[:internal_link_hosts]).to eq(
          "forum.example.com" => "/forum",
          "old.example.com" => nil,
          "older.example.com" => nil,
        )
        expect(args[:internal_link_base_prefix]).to eq("/forum")
      end

      it "keeps a distinct prefix per entry (root former domain, subfolder base)" do
        args =
          posts_args(
            source_site: {
              base_url: "https://www.example.com/community",
              former_domains: %w[https://old.example.com https://legacy.example.com/board],
            },
          )

        expect(args[:internal_link_hosts]).to eq(
          "www.example.com" => "/community",
          "old.example.com" => nil,
          "legacy.example.com" => "/board",
        )
        expect(args[:internal_link_base_prefix]).to eq("/community")
      end

      it "leaves the base prefix nil when the base URL sits at the root" do
        args =
          posts_args(
            source_site: {
              base_url: "https://forum.example.com",
              former_domains: %w[https://old.example.com/forum],
            },
          )

        expect(args[:internal_link_hosts]).to eq(
          "forum.example.com" => nil,
          "old.example.com" => "/forum",
        )
        expect(args[:internal_link_base_prefix]).to be_nil
      end

      it "drops the port and normalizes a trailing slash in the prefix" do
        args =
          posts_args(
            source_site: {
              base_url: "https://forum.example.com:8080/forum/",
              former_domains: %w[old.example.com],
            },
          )

        expect(args[:internal_link_hosts]).to eq(
          "forum.example.com" => "/forum",
          "old.example.com" => nil,
        )
        expect(args[:internal_link_base_prefix]).to eq("/forum")
      end

      it "leaves the host map empty and the base prefix nil with no source site" do
        args = posts_args

        expect(args[:internal_link_hosts]).to be_empty
        expect(args[:internal_link_base_prefix]).to be_nil
      end

      it "raises a clear error for a malformed source_site URL" do
        expect { posts_args(source_site: { base_url: "https://exa mple.com" }) }.to raise_error(
          /Invalid source_site URL/,
        )
      end
    end
  end
end
