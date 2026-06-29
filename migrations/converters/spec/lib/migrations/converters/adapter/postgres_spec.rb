# frozen_string_literal: true

RSpec.describe Migrations::Converters::Adapter::Postgres do
  def create_adapter(settings = {})
    adapter = described_class.new(settings)
    yield adapter
  ensure
    adapter&.close
  end

  context "with a stubbed connection" do
    let(:connection) { instance_double(PG::Connection) }
    let(:socket_io) { instance_double(IO) }

    before do
      allow(PG::Connection).to receive(:new).and_return(connection)
      allow(PG::BasicTypeMapForResults).to receive(:new).with(connection).and_return(
        instance_double(PG::BasicTypeMapForResults),
      )

      allow(connection).to receive(:type_map_for_results=)
      allow(connection).to receive(:field_name_type=)
      allow(connection).to receive(:exec)
      allow(connection).to receive(:socket_io).and_return(socket_io)
      allow(connection).to receive(:finished?).and_return(false)
      allow(connection).to receive(:finish)
      allow(connection).to receive(:quote_ident) { |id| %("#{id}") }
      allow(connection).to receive(:escape_string) { |str| str }
      allow(socket_io).to receive(:reopen)
    end

    it "registers a fork hook on creation and removes it on `close`" do
      expect(Migrations::ForkManager.hook_count).to eq(0)

      create_adapter do |adapter|
        expect(Migrations::ForkManager.hook_count).to eq(1)
        adapter.close
        expect(Migrations::ForkManager.hook_count).to eq(0)
      end
    end

    describe "#partition_bounds" do
      it "returns the key's min and max" do
        allow(connection).to receive(:exec).with(/MIN\(topic_id\)/).and_return(
          [{ min: 0, max: 99 }],
        )
        create_adapter do |adapter|
          expect(adapter.partition_bounds(:topic_id, "topic_users", "user_id > 0")).to eq([0, 99])
        end
      end
    end

    describe "#estimated_row_count" do
      it "reads the planner's row estimate" do
        allow(connection).to receive(:exec).with(/reltuples/).and_return([{ reltuples: 1234 }])
        create_adapter { |adapter| expect(adapter.estimated_row_count("things")).to eq(1234) }
      end
    end

    describe "#boundaries_by_scan" do
      it "returns each bucket's first value" do
        create_adapter do |adapter|
          allow(adapter).to receive(:query).and_return([{ id: 0 }, { id: 50 }])
          expect(adapter.boundaries_by_scan(:id, "things", nil, 2)).to eq([0, 50])
        end
      end

      it "returns a tuple per bucket for a composite key" do
        create_adapter do |adapter|
          allow(adapter).to receive(:query).and_return(
            [{ topic_id: 1, user_id: 10 }, { topic_id: 2, user_id: 5 }],
          )
          expect(adapter.boundaries_by_scan(%i[topic_id user_id], "topic_users", nil, 2)).to eq(
            [[1, 10], [2, 5]],
          )
        end
      end

      it "drops duplicate boundaries from buckets that share a value" do
        create_adapter do |adapter|
          allow(adapter).to receive(:query).and_return([{ id: 5 }, { id: 5 }])
          expect(adapter.boundaries_by_scan(:id, "things", nil, 2)).to eq([5])
        end
      end
    end

    describe "#chunk_filter" do
      def chunk(lower, upper, base: "user_id > 0")
        create_adapter { |adapter| adapter.chunk_filter(:topic_id, lower, upper, base:) }
      end

      it "limits to a half-open numeric range, AND-ed with the base" do
        expect(chunk(25, 50)).to eq("user_id > 0 AND topic_id >= 25 AND topic_id < 50")
      end

      it "drops the upper bound for an open-ended chunk" do
        expect(chunk(75, nil)).to eq("user_id > 0 AND topic_id >= 75")
      end

      it "is just the base filter when there's no chunk" do
        expect(chunk(nil, nil)).to eq("user_id > 0")
      end

      it "is just the chunk conditions when there's no base" do
        create_adapter do |adapter|
          expect(adapter.chunk_filter(:topic_id, 25, 50)).to eq("topic_id >= 25 AND topic_id < 50")
        end
      end

      it "quotes a text key (UUID, etc.)" do
        create_adapter do |adapter|
          expect(adapter.chunk_filter(:id, "uuid-a", "uuid-b")).to eq(
            "id >= 'uuid-a' AND id < 'uuid-b'",
          )
        end
      end

      it "compares a composite key as a row value" do
        create_adapter do |adapter|
          expect(
            adapter.chunk_filter(%i[topic_id user_id], [1, 10], [2, 5], base: "user_id > 0"),
          ).to eq("user_id > 0 AND (topic_id, user_id) >= (1, 10) AND (topic_id, user_id) < (2, 5)")
        end
      end

      it "leaves the upper off for an open-ended composite chunk" do
        create_adapter do |adapter|
          expect(adapter.chunk_filter(%i[topic_id user_id], [2, 5], nil)).to eq(
            "(topic_id, user_id) >= (2, 5)",
          )
        end
      end
    end

    describe "#select_all and #count_all" do
      it "selects all rows from a quoted table" do
        create_adapter do |adapter|
          allow(adapter).to receive(:query).with('SELECT * FROM "things" WHERE active').and_return(
            [:row],
          )
          expect(adapter.select_all("things", where: "active")).to eq([:row])
        end
      end

      it "counts rows in a quoted table" do
        create_adapter do |adapter|
          allow(adapter).to receive(:count).with(
            'SELECT COUNT(*) FROM "things" WHERE active',
          ).and_return(7)
          expect(adapter.count_all("things", where: "active")).to eq(7)
        end
      end

      it "omits the WHERE clause when there's no filter" do
        create_adapter do |adapter|
          allow(adapter).to receive(:query).with('SELECT * FROM "things"').and_return([:row])
          expect(adapter.select_all("things")).to eq([:row])
        end
      end
    end

    describe "#discard!" do
      it "redirects the connection's socket to the null device without closing it" do
        create_adapter do |adapter|
          adapter.discard!

          expect(socket_io).to have_received(:reopen).with(IO::NULL)
          expect(connection).to_not have_received(:finish)
        end
      end

      it "raises a `DiscardedError` when the adapter is used afterwards" do
        create_adapter do |adapter|
          adapter.discard!

          expect { adapter.exec("SELECT 1") }.to raise_error(described_class::DiscardedError)
          expect { adapter.query("SELECT 1") }.to raise_error(described_class::DiscardedError)
          expect { adapter.query_value("SELECT 1") }.to raise_error(described_class::DiscardedError)
        end
      end

      it "ignores connections that no longer expose a usable socket" do
        allow(connection).to receive(:socket_io).and_raise(PG::ConnectionBad)

        create_adapter { |adapter| expect { adapter.discard! }.to_not raise_error }
      end

      it "can be followed by `close` without errors" do
        create_adapter do |adapter|
          adapter.discard!

          expect { adapter.close }.to_not raise_error
          expect(connection).to_not have_received(:finish)
          expect(Migrations::ForkManager.hook_count).to eq(0)
        end
      end
    end

    context "when `Migrations::ForkManager.fork` is used" do
      it "discards the adapter in the child process, but not in the parent" do
        create_adapter do |adapter|
          pid =
            Migrations::ForkManager.fork do
              adapter.exec("SELECT 1")
              exit!(1)
            rescue described_class::DiscardedError
              exit!(0)
            end

          _, status = Process.waitpid2(pid)
          expect(status.exitstatus).to eq(0)

          expect { adapter.exec("SELECT 1") }.to_not raise_error
        end
      end

      it "no longer discards the adapter in child processes after `close`" do
        create_adapter do |adapter|
          allow(adapter).to receive(:discard!).and_call_original
          adapter.close

          pid =
            Migrations::ForkManager.fork do
              expect(adapter).to_not have_received(:discard!)
              exit!(0)
            rescue RSpec::Expectations::ExpectationNotMetError
              exit!(1)
            end

          _, status = Process.waitpid2(pid)
          expect(status.exitstatus).to eq(0)
        end
      end
    end
  end

  context "with a real database connection", :rails do
    def create_adapter(&block)
      config = ActiveRecord::Base.connection_db_config.configuration_hash

      super(
        {
          host: config[:host],
          port: config[:port],
          user: config[:username],
          password: config[:password],
          dbname: config[:database],
        }.compact,
        &block
      )
    end

    it "keeps the connection of the main process usable after a forked process exits" do
      create_adapter do |adapter|
        expect(adapter.query_value("SELECT 1")).to eq(1)

        # An empty fork is all it takes: without `discard!` the pg gem's
        # cleanup at child exit sends a libpq Terminate message over the
        # shared socket and the server closes the parent's session.
        _, status = Process.waitpid2(Migrations::ForkManager.fork {})
        expect(status).to be_success

        expect(adapter.query_value("SELECT 1")).to eq(1)
      end
    end

    it "doesn't disturb an in-flight single-row-mode stream in the main process" do
      create_adapter do |adapter|
        rows = adapter.query("SELECT i FROM generate_series(1, 100) AS s(i)")
        expect(rows.next).to eq({ i: 1 })

        # With concurrently running steps, workers fork while another step's
        # source is still streaming results. The child-side discard must
        # leave that stream alone; this is why there's no parent-side
        # `before_fork` close/reopen for this connection.
        _, status = Process.waitpid2(Migrations::ForkManager.fork {})
        expect(status).to be_success

        remaining = []
        loop { remaining << rows.next }
        expect(remaining.size).to eq(99)

        expect(adapter.query_value("SELECT 1")).to eq(1)
      end
    end
  end
end
