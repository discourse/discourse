# frozen_string_literal: true

require 'rails_helper'
require 'csv'

describe Jobs::ExportUserArchive do
  context '#execute' do
    let(:user) { Fabricate(:user, username: "john_doe") }
    let(:post) { Fabricate(:post, user: user) }

    before do
      _ = post
      user.user_profile.website = 'https://doe.example.com/john'
      user.user_profile.save
    end

    after do
      user.uploads.each(&:destroy!)
    end

    it 'raises an error when the user is missing' do
      expect { Jobs::ExportCsvFile.new.execute(user_id: user.id + (1 << 20)) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'works' do
      expect do
        Jobs::ExportUserArchive.new.execute(
          user_id: user.id,
        )
      end.to change { Upload.count }.by(1)

      system_message = user.topics_allowed.last

      expect(system_message.title).to eq(I18n.t(
        "system_messages.csv_export_succeeded.subject_template",
        export_title: "User Archive"
      ))

      upload = system_message.first_post.uploads.first

      expect(system_message.first_post.raw).to eq(I18n.t(
        "system_messages.csv_export_succeeded.text_body_template",
        download_link: "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.filesize} Bytes)"
      ).chomp)

      expect(system_message.id).to eq(UserExport.last.topic_id)
      expect(system_message.closed).to eq(true)

      files = []
      Zip::File.open(Discourse.store.path_for(upload)) do |zip_file|
        zip_file.each { |entry| files << entry.name }
      end

      expect(files.size).to eq(Jobs::ExportUserArchive::COMPONENTS.length)
      expect(files.find { |f| f.match 'user_archive-john_doe-' }).to_not be_nil
      expect(files.find { |f| f.match 'user_archive_profile-john_doe-' }).to_not be_nil
    end
  end

  context 'user_archive posts' do
    let(:component) { 'user_archive' }
    let(:user) { Fabricate(:user, username: "john_doe") }
    let(:user2) { Fabricate(:user) }
    let(:job) {
      j = Jobs::ExportUserArchive.new
      j.current_user = user
      j
    }
    let(:category) { Fabricate(:category_with_definition) }
    let(:subcategory) { Fabricate(:category_with_definition, parent_category_id: category.id) }
    let(:subsubcategory) { Fabricate(:category_with_definition, parent_category_id: subcategory.id) }
    let(:subsubtopic) { Fabricate(:topic, category: subsubcategory) }
    let(:subsubpost) { Fabricate(:post, user: user, topic: subsubtopic) }

    let(:topic) { Fabricate(:topic, category: category) }
    let(:normal_post) { Fabricate(:post, user: user, topic: topic) }
    let(:reply) { PostCreator.new(user2, raw: 'asdf1234qwert7896', topic_id: topic.id, reply_to_post_number: normal_post.post_number).create }

    let(:message) { Fabricate(:private_message_topic) }
    let(:message_post) { Fabricate(:post, user: user, topic: message) }

    it 'properly exports posts' do
      SiteSetting.max_category_nesting = 3
      [reply, subsubpost, message_post]

      PostActionCreator.like(user2, normal_post)

      rows = []
      job.user_archive_export do |row|
        rows << Jobs::ExportUserArchive::HEADER_ATTRS_FOR['user_archive'].zip(row).to_h
      end

      expect(rows.length).to eq(3)

      post1 = rows.find { |r| r['topic_title'] == topic.title }
      post2 = rows.find { |r| r['topic_title'] == subsubtopic.title }
      post3 = rows.find { |r| r['topic_title'] == message.title }

      expect(post1["categories"]).to eq("#{category.name}")
      expect(post2["categories"]).to eq("#{category.name}|#{subcategory.name}|#{subsubcategory.name}")
      expect(post3["categories"]).to eq("-")

      expect(post1["is_pm"]).to eq(I18n.t("csv_export.boolean_no"))
      expect(post2["is_pm"]).to eq(I18n.t("csv_export.boolean_no"))
      expect(post3["is_pm"]).to eq(I18n.t("csv_export.boolean_yes"))

      expect(post1["post"]).to eq(normal_post.raw)
      expect(post2["post"]).to eq(subsubpost.raw)
      expect(post3["post"]).to eq(message_post.raw)

      expect(post1['like_count']).to eq(1)
      expect(post2['like_count']).to eq(0)

      expect(post1['reply_count']).to eq(1)
      expect(post2['reply_count']).to eq(0)
    end

  end

  context 'user_archive_profile' do
    let(:component) { 'user_archive_profile' }
    let(:user) { Fabricate(:user, username: "john_doe") }
    let(:job) {
      j = Jobs::ExportUserArchive.new
      j.current_user = user
      j
    }

    before do
      user.user_profile.website = 'https://doe.example.com/john'
      user.user_profile.bio_raw = "I am John Doe\n\nHere I am"
      user.user_profile.save
    end

    it 'properly includes the profile fields' do
      csv_out = CSV.generate do |csv|
        csv << job.get_header(component)
        job.user_archive_profile_export.each { |d| csv << d }
      end

      expect(csv_out).to match('doe.example.com')
      expect(csv_out).to match("Doe\n\nHere")
    end
  end

end
