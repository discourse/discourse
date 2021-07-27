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

  describe '#notify_user' do
    before { STDOUT.stubs(:write) }

    it 'include upload' do
      backuper = BackupRestore::Backuper.new(Discourse.system_user.id)
      expect { backuper.send(:notify_user) }
        .to change { Topic.private_messages.count }.by(1)
        .and change { Upload.where(original_filename: "log.txt.zip").count }.by(1)
    end

    it 'includes upload error if cannot save upload' do
      SiteSetting.max_export_file_size_kb = 1
      SiteSetting.export_authorized_extensions = "tar.gz"

      backuper = BackupRestore::Backuper.new(Discourse.system_user.id)
      expect { backuper.send(:notify_user) }
        .to change { Topic.private_messages.count }.by(1)
        .and change { Upload.count }.by(0)
    end
  end
end
