require 'rails_helper'

describe BackupRestore::Restorer do
  it 'detects which pg_dump output is restorable to different schemas' do
    expect(BackupRestore::Restorer.pg_produces_portable_dump? "9.6.7").to be true
    expect(BackupRestore::Restorer.pg_produces_portable_dump? "9.6.8").to be false
    expect(BackupRestore::Restorer.pg_produces_portable_dump? "9.6.9").to be false

    expect(BackupRestore::Restorer.pg_produces_portable_dump? "10.2").to be true
    expect(BackupRestore::Restorer.pg_produces_portable_dump? "10.3").to be false
    expect(BackupRestore::Restorer.pg_produces_portable_dump? "10.4").to be false
  end
end
