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
    before do
      freeze_time Time.zone.parse('2010-01-01 12:00')
    end

    it 'includes logs if short' do
      SiteSetting.max_export_file_size_kb = 1
      SiteSetting.export_authorized_extensions = "tar.gz"

      silence_stdout do
        backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

        expect { backuper.send(:notify_user) }
          .to change { Topic.private_messages.count }.by(1)
          .and change { Upload.count }.by(0)
      end

      expect(Topic.last.first_post.raw).to include("```text\n[2010-01-01 12:00:00] Notifying 'system' of the end of the backup...\n```")
    end

    it 'include upload if log is long' do
      SiteSetting.max_post_length = 250

      silence_stdout do
        backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

        expect { backuper.send(:notify_user) }
          .to change { Topic.private_messages.count }.by(1)
          .and change { Upload.where(original_filename: "log.txt.zip").count }.by(1)
      end

      expect(Topic.last.first_post.raw).to include("[log.txt.zip|attachment]")
    end

    it 'includes trimmed logs if log is long and upload cannot be saved' do
      SiteSetting.max_post_length = 348
      SiteSetting.max_export_file_size_kb = 1
      SiteSetting.export_authorized_extensions = "tar.gz"

      silence_stdout do
        backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

        1.upto(10).each do |i|
          backuper.send(:log, "Line #{i}")
        end

        expect { backuper.send(:notify_user) }
          .to change { Topic.private_messages.count }.by(1)
          .and change { Upload.count }.by(0)
      end

      expect(Topic.last.first_post.raw).to include("```text\n...\n[2010-01-01 12:00:00] Line 10\n[2010-01-01 12:00:00] Notifying 'system' of the end of the backup...\n```")
    end
  end
end
