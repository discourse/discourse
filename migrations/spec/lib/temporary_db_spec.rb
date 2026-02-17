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
end
