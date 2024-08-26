# frozen_string_literal: true

require "extralite"

RSpec.describe ::Migrations::Database::PreparedStatementCache do
  let(:cache) { described_class.new(3) }

  def create_statement_double
    instance_double(Extralite::Query, close: nil)
  end

  it "should inherit behavior from LruRedux::Cache" do
    expect(described_class).to be < LruRedux::Cache
  end

  it "closes the statement when an old entry is removed" do
    cache["a"] = a_statement = create_statement_double
    cache["b"] = b_statement = create_statement_double
    cache["c"] = c_statement = create_statement_double

    # this should remove the oldest entry "a" from the cache and call #close on the statement
    cache["d"] = d_statement = create_statement_double

    expect(a_statement).to have_received(:close)
    expect(b_statement).not_to have_received(:close)
    expect(c_statement).not_to have_received(:close)
    expect(d_statement).not_to have_received(:close)
  end

  it "closes all statements when the cache is cleared" do
    cache["a"] = a_statement = create_statement_double
    cache["b"] = b_statement = create_statement_double
    cache["c"] = c_statement = create_statement_double

    cache.clear

    expect(a_statement).to have_received(:close)
    expect(b_statement).to have_received(:close)
    expect(c_statement).to have_received(:close)
  end
end
