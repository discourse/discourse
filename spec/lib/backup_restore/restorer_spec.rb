require 'rails_helper'

describe BackupRestore::Restorer do
  it 'detects which pg_dump output is restorable to different schemas' do
    {
      "9.6.7" => true,
      "9.6.8" => false,
      "9.6.9" => false,
      "10.2" => true,
      "10.3" => false,
      "10.3.1" => false,
      "10.4" => false,
    }.each do |key, value|
      expect(described_class.pg_produces_portable_dump?(key)).to eq(value)
    end
  end
end
