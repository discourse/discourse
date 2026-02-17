# frozen_string_literal: true

RSpec.describe TemporaryDb do
  it "uses a unique temporary path per instance" do
    first = described_class.new
    second = described_class.new

    first_path = first.instance_variable_get(:@pg_temp_path)
    second_path = second.instance_variable_get(:@pg_temp_path)

    expect(first_path).not_to eq(second_path)
    expect(first_path).to include("pg_schema_tmp_")
    expect(second_path).to include("pg_schema_tmp_")
  end

  it "starts free-port scanning from a randomized offset" do
    db = described_class.new

    allow(SecureRandom).to receive(:random_number).with(3).and_return(1)
    allow(db).to receive(:port_available?).and_wrap_original do |_original, port|
      port == 102
    end

    expect(db.find_free_port(100..102)).to eq(102)
    expect(db).to have_received(:port_available?).with(101)
    expect(db).to have_received(:port_available?).with(102)
  end
end
