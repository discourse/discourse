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
          expect { adapter.reset }.to raise_error(described_class::DiscardedError)
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
