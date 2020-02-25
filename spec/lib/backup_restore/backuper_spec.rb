# frozen_string_literal: true

require 'rails_helper'

describe BackupRestore::Backuper do
  it 'returns a non-empty parameterized title when site title contains unicode' do
    SiteSetting.title = 'Ɣ'
    backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

    expect(backuper.send(:get_parameterized_title)).to eq("discourse")
  end

  it 'returns a valid parameterized site title' do
    SiteSetting.title = "Coding Horror"
    backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

    expect(backuper.send(:get_parameterized_title)).to eq("coding-horror")
  end
end
