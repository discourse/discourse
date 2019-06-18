# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::CleanUpUserExportTopics do
  fab!(:user) { Fabricate(:user) }

  it 'should delete ancient user export system messages' do
    post_en = SystemMessage.create_from_system_user(
      user,
      :csv_export_succeeded,
      download_link: "http://example.com/download",
      file_name: "xyz_en.gz",
      file_size: "55",
      export_title: "user_archive"
    )
    topic_en = post_en.topic
    topic_en.update!(created_at: 5.days.ago)

    I18n.locale = :fr
    post_fr = SystemMessage.create_from_system_user(
      user,
      :csv_export_succeeded,
      download_link: "http://example.com/download",
      file_name: "xyz_fr.gz",
      file_size: "56",
      export_title: "user_archive"
    )
    topic_fr = post_fr.topic
    topic_fr.update!(created_at: 5.days.ago)

    described_class.new.execute_onceoff({})

    expect(Topic.with_deleted.exists?(id: topic_en.id)).to eq(false)
    expect(Topic.with_deleted.exists?(id: topic_fr.id)).to eq(false)
  end
end
