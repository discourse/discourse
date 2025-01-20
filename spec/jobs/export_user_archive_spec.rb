# frozen_string_literal: true

require "csv"

RSpec.describe Jobs::ExportUserArchive do
  fab!(:user) { Fabricate(:user, username: "john_doe", refresh_auto_groups: true) }
  fab!(:user2) { Fabricate(:user) }
  let(:extra) { {} }
  let(:job) do
    j = Jobs::ExportUserArchive.new
    j.archive_for_user = user
    j.extra = extra
    j
  end
  let(:component) { raise "component not set" }

  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:category) { Fabricate(:category_with_definition, name: "User Archive Category") }
  fab!(:subcategory) { Fabricate(:category_with_definition, parent_category_id: category.id) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  let(:post) { Fabricate(:post, user: user, topic: topic) }

  def make_component_csv
    data_rows = []
    csv_out =
      CSV.generate do |csv|
        csv << job.get_header(component)
        job.public_send(:"#{component}_export") do |row|
          csv << row
          data_rows << Jobs::ExportUserArchive::HEADER_ATTRS_FOR[component]
            .zip(row.map(&:to_s))
            .to_h
            .with_indifferent_access
        end
      end
    [data_rows, csv_out]
  end

  def make_component_json
    JSON.parse(MultiJson.dump(job.public_send(:"#{component}_export")))
  end

  describe "#execute" do
    before do
      _ = post
      user.user_profile.website = "https://doe.example.com/john"
      user.user_profile.save
      # force a UserAuthTokenLog entry
      env =
        create_request_env.merge(
          "HTTP_USER_AGENT" => "MyWebBrowser",
          "REQUEST_PATH" => "/some_path/456852",
        )
      cookie_jar = ActionDispatch::Request.new(env).cookie_jar
      Discourse.current_user_provider.new(env).log_on_user(user, {}, cookie_jar)

      # force a nonstandard post action
      PostAction.new(user: user, post: post, post_action_type_id: 5).save
    end

    after { user.uploads.each(&:destroy!) }

    it "raises an error when the user is missing" do
      expect { Jobs::ExportCsvFile.new.execute(user_id: user.id + (1 << 20)) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "works" do
      expect do Jobs::ExportUserArchive.new.execute(user_id: user.id) end.to change {
        Upload.count
      }.by(1)

      system_message = user.topics_allowed.last

      expect(system_message.title).to eq(
        I18n.t(
          "system_messages.csv_export_succeeded.subject_template",
          export_title: "User Archive",
        ),
      )

      upload = system_message.first_post.uploads.first

      expect(system_message.first_post.raw).to eq(
        I18n.t(
          "system_messages.csv_export_succeeded.text_body_template",
          download_link:
            "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.human_filesize})",
        ).chomp,
      )

      expect(system_message.id).to eq(UserExport.last.topic_id)
      expect(system_message.closed).to eq(true)

      files = []
      Zip::File.open(Discourse.store.path_for(upload)) do |zip_file|
        zip_file.each { |entry| files << entry.name }
      end

      expect(files.size).to eq(Jobs::ExportUserArchive::COMPONENTS.length)
      expect(files.find { |f| f == "user_archive.csv" }).to_not be_nil
      expect(files.find { |f| f == "category_preferences.csv" }).to_not be_nil
    end

    it "sends a message if it fails" do
      SiteSetting.max_export_file_size_kb = 1

      expect do Jobs::ExportUserArchive.new.execute(user_id: user.id) end.not_to change {
        Upload.count
      }

      system_message = user.topics_allowed.last
      expect(system_message.title).to eq(
        I18n.t("system_messages.csv_export_failed.subject_template"),
      )
    end

    context "with a requesting_user_id that is not the user being exported" do
      it "raises an error when not admin" do
        expect do
          Jobs::ExportUserArchive.new.execute(
            user_id: user.id,
            admin: {
              requesting_user_id: user2.id,
            },
          )
        end.to raise_error(
          Discourse::InvalidParameters,
          "requesting_user_id: can only be admins when specified",
        )
      end

      it "creates the upload and defaults to sending the message to the specified requesting_user_id" do
        expect do
          Jobs::ExportUserArchive.new.execute(
            user_id: user2.id,
            admin: {
              requesting_user_id: admin.id,
            },
          )
        end.to change { Upload.count }.by(1)

        system_message = admin.topics_allowed.last

        expect(system_message.title).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.subject_template",
            export_title: "User Archive",
          ),
        )

        upload = system_message.first_post.uploads.first

        expect(system_message.first_post.raw).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.text_body_template",
            download_link:
              "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.human_filesize})",
          ).chomp,
        )
      end

      it "creates the upload and sends it to the original user if the send_to_user flag is set" do
        expect do
          Jobs::ExportUserArchive.new.execute(
            user_id: user.id,
            admin: {
              requesting_user_id: admin.id,
              send_to_user: true,
            },
          )
        end.to change { Upload.count }.by(1)

        system_message = user.topics_allowed.last

        expect(system_message.title).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.subject_template",
            export_title: "User Archive",
          ),
        )

        upload = system_message.first_post.uploads.first

        expect(system_message.first_post.raw).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.text_body_template",
            download_link:
              "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.human_filesize})",
          ).chomp,
        )
      end

      it "creates the upload and sends it to the admin if the send_to_admin flag is set" do
        expect do
          Jobs::ExportUserArchive.new.execute(
            user_id: user.id,
            admin: {
              requesting_user_id: admin.id,
              send_to_admin: true,
            },
          )
        end.to change { Upload.count }.by(1)

        system_message = admin.topics_allowed.last

        expect(system_message.title).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.subject_template",
            export_title: "User Archive",
          ),
        )

        upload = system_message.first_post.uploads.first

        expect(system_message.first_post.raw).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.text_body_template",
            download_link:
              "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.human_filesize})",
          ).chomp,
        )
      end

      it "creates the upload and sends it to the site contact if the send_to_site_contact flag is set" do
        site_contact = Fabricate(:user, admin: true)
        SiteSetting.site_contact_username = site_contact.username.downcase

        expect do
          Jobs::ExportUserArchive.new.execute(
            user_id: user.id,
            admin: {
              requesting_user_id: admin.id,
              send_to_site_contact: true,
            },
          )
        end.to change { Upload.count }.by(1)

        system_message = site_contact.topics_allowed.last

        expect(system_message.title).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.subject_template",
            export_title: "User Archive",
          ),
        )

        upload = system_message.first_post.uploads.first

        expect(system_message.first_post.raw).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.text_body_template",
            download_link:
              "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.human_filesize})",
          ).chomp,
        )
      end

      it "creates the upload and sends it to the original user, even when that user is suspended" do
        user.suspended_till = 1.day.from_now
        user.save!

        expect do
          Jobs::ExportUserArchive.new.execute(
            user_id: user.id,
            admin: {
              requesting_user_id: admin.id,
              send_to_user: true,
            },
          )
        end.to change { Upload.count }.by(1)

        system_message = user.topics_allowed.last

        expect(system_message.title).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.subject_template",
            export_title: "User Archive",
          ),
        )

        upload = system_message.first_post.uploads.first

        expect(system_message.first_post.raw).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.text_body_template",
            download_link:
              "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.human_filesize})",
          ).chomp,
        )
      end
    end
  end

  describe "user_archive posts" do
    let(:component) { "user_archive" }
    let(:subsubcategory) do
      Fabricate(:category_with_definition, parent_category_id: subcategory.id)
    end
    let(:subsubtopic) { Fabricate(:topic, category: subsubcategory) }
    let(:subsubpost) { Fabricate(:post, user: user, topic: subsubtopic) }

    let(:normal_post) { Fabricate(:post, user: user, topic: topic) }
    let(:reply) do
      PostCreator.new(
        user2,
        raw: "asdf1234qwert7896",
        topic_id: topic.id,
        reply_to_post_number: normal_post.post_number,
      ).create
    end

    let(:message) { Fabricate(:private_message_topic) }
    let(:message_post) { Fabricate(:post, user: user, topic: message) }

    it "properly exports posts" do
      SiteSetting.max_category_nesting = 3
      [reply, subsubpost, message_post]

      PostActionCreator.like(user2, normal_post)

      rows = []
      job.user_archive_export do |row|
        rows << Jobs::ExportUserArchive::HEADER_ATTRS_FOR["user_archive"].zip(row).to_h
      end

      expect(rows.length).to eq(3)

      post1 = rows.find { |r| r["topic_title"] == topic.title }
      post2 = rows.find { |r| r["topic_title"] == subsubtopic.title }
      post3 = rows.find { |r| r["topic_title"] == message.title }

      expect(post1["categories"]).to eq("#{category.name}")
      expect(post2["categories"]).to eq(
        "#{category.name}|#{subcategory.name}|#{subsubcategory.name}",
      )
      expect(post3["categories"]).to eq("-")

      expect(post1["is_pm"]).to eq(I18n.t("csv_export.boolean_no"))
      expect(post2["is_pm"]).to eq(I18n.t("csv_export.boolean_no"))
      expect(post3["is_pm"]).to eq(I18n.t("csv_export.boolean_yes"))

      expect(post1["post_raw"]).to eq(normal_post.raw)
      expect(post2["post_raw"]).to eq(subsubpost.raw)
      expect(post3["post_raw"]).to eq(message_post.raw)

      expect(post1["post_cooked"]).to eq(normal_post.cooked)
      expect(post2["post_cooked"]).to eq(subsubpost.cooked)
      expect(post3["post_cooked"]).to eq(message_post.cooked)

      expect(post1["like_count"]).to eq(1)
      expect(post2["like_count"]).to eq(0)

      expect(post1["reply_count"]).to eq(1)
      expect(post2["reply_count"]).to eq(0)
    end

    it "can export a post from a deleted category" do
      cat2 = Fabricate(:category)
      topic2 = Fabricate(:topic, category: cat2, user: user)
      _post2 = Fabricate(:post, topic: topic2, user: user)

      cat2_id = cat2.id
      cat2.destroy!

      _, csv_out = make_component_csv
      expect(csv_out).to match cat2_id.to_s
    end

    it "can export a post from a secure category, obscuring the category name" do
      cat2 = Fabricate(:private_category, group: Fabricate(:group), name: "Secret Cat")
      topic2 = Fabricate(:topic, category: cat2, user: user, title: "This is a test secure topic")
      _post2 = Fabricate(:post, topic: topic2, user: user)
      data, csv_out = make_component_csv
      expect(csv_out).not_to match "Secret Cat"
      expect(data.length).to eq(1)
      expect(data[0][:topic_title]).to eq("This is a test secure topic")
      expect(data[0][:categories]).to eq("-")
    end
  end

  describe "preferences" do
    let(:component) { "preferences" }

    before do
      user.user_profile.website = "https://doe.example.com/john"
      user.user_profile.bio_raw = "I am John Doe\n\nHere I am"
      user.user_profile.save
      user.user_option.text_size = :smaller
      user.user_option.automatically_unpin_topics = false
      user.user_option.save
    end

    it "properly includes the profile fields" do
      _serializer = job.preferences_export
      # puts MultiJson.dump(serializer, indent: 4)
      output = make_component_json
      payload = output["user"]

      expect(payload["website"]).to match("doe.example.com")
      expect(payload["bio_raw"]).to match("Doe\n\nHere")
      expect(payload["user_option"]["automatically_unpin_topics"]).to eq(false)
      expect(payload["user_option"]["text_size"]).to eq("smaller")
    end
  end

  describe "auth tokens" do
    let(:component) { "auth_tokens" }

    before do
      env =
        create_request_env.merge(
          "HTTP_USER_AGENT" => "MyWebBrowser",
          "REQUEST_PATH" => "/some_path/456852",
        )
      cookie_jar = ActionDispatch::Request.new(env).cookie_jar
      Discourse.current_user_provider.new(env).log_on_user(user, {}, cookie_jar)
    end

    it "properly includes session records" do
      data, _csv_out = make_component_csv
      expect(data.length).to eq(1)

      expect(data[0]["user_agent"]).to eq("MyWebBrowser")
    end

    context "with auth token logs" do
      let(:component) { "auth_token_logs" }
      it "includes details such as the path" do
        data, _csv_out = make_component_csv
        expect(data.length).to eq(1)

        expect(data[0]["action"]).to eq("generate")
        expect(data[0]["path"]).to eq("/some_path/456852")
      end
    end
  end

  describe "badges" do
    let(:component) { "badges" }

    let(:badge1) { Fabricate(:badge) }
    let(:badge2) { Fabricate(:badge, multiple_grant: true) }
    let(:badge3) { Fabricate(:badge, multiple_grant: true) }
    let(:day_ago) { 1.day.ago }

    it "properly includes badge records" do
      grant_start = Time.now.utc
      BadgeGranter.grant(badge1, user)
      BadgeGranter.grant(badge2, user)
      BadgeGranter.grant(badge2, user, granted_by: admin)
      BadgeGranter.grant(badge3, user, post_id: Fabricate(:post).id)
      BadgeGranter.grant(badge3, user, post_id: Fabricate(:post).id)
      BadgeGranter.grant(badge3, user, post_id: Fabricate(:post).id)

      data, _csv_out = make_component_csv
      expect(data.length).to eq(6)

      expect(data[0]["badge_id"]).to eq(badge1.id.to_s)
      expect(data[0]["badge_name"]).to eq(badge1.display_name)
      expect(data[0]["featured_rank"]).to_not eq("")
      expect(DateTime.parse(data[0]["granted_at"])).to be >= DateTime.parse(grant_start.to_s)
      expect(data[2]["granted_manually"]).to eq("true")
      expect(Post.find(data[3]["post_id"])).to_not be_nil
    end
  end

  describe "bookmarks" do
    let(:component) { "bookmarks" }

    let(:name) { "Collect my thoughts on this" }
    let(:manager) { BookmarkManager.new(user) }
    let(:topic1) { Fabricate(:topic) }
    let(:post1) { Fabricate(:post, topic: topic1, post_number: 5) }
    let(:post2) { Fabricate(:post) }
    let(:post3) { Fabricate(:post) }
    let(:private_message_topic) { Fabricate(:private_message_topic) }
    let(:post4) { Fabricate(:post, topic: private_message_topic) }
    let(:reminder_at) { 1.day.from_now }

    it "properly includes bookmark records" do
      now = freeze_time "2017-03-01 12:00"

      bookmark1 =
        manager.create_for(bookmarkable_id: post1.id, bookmarkable_type: "Post", name: name)
      update1_at = now + 1.hours
      bookmark1.update(name: "great food recipe", updated_at: update1_at)

      manager.create_for(
        bookmarkable_id: post2.id,
        bookmarkable_type: "Post",
        name: name,
        reminder_at: reminder_at,
        options: {
          auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent],
        },
      )
      twelve_hr_ago = freeze_time now - 12.hours
      pending_reminder =
        manager.create_for(
          bookmarkable_id: post3.id,
          bookmarkable_type: "Post",
          name: name,
          reminder_at: now - 8.hours,
        )
      freeze_time now

      tau_record = private_message_topic.topic_allowed_users.create!(user_id: user.id)
      manager.create_for(bookmarkable_id: post4.id, bookmarkable_type: "Post", name: name)
      tau_record.destroy!

      BookmarkReminderNotificationHandler.new(pending_reminder).send_notification

      data, _csv_out = make_component_csv

      expect(data.length).to eq(4)

      expect(data[0]["bookmarkable_id"]).to eq(post1.id.to_s)
      expect(data[0]["bookmarkable_type"]).to eq("Post")
      expect(data[0]["link"]).to eq(post1.full_url)
      expect(DateTime.parse(data[0]["updated_at"])).to eq(DateTime.parse(update1_at.to_s))

      expect(data[1]["name"]).to eq(name)
      expect(DateTime.parse(data[1]["reminder_at"])).to eq(DateTime.parse(reminder_at.to_s))
      expect(data[1]["auto_delete_preference"]).to eq("when_reminder_sent")

      expect(DateTime.parse(data[2]["created_at"])).to eq(DateTime.parse(twelve_hr_ago.to_s))
      expect(DateTime.parse(data[2]["reminder_last_sent_at"])).to eq(DateTime.parse(now.to_s))
      expect(data[2]["reminder_set_at"]).to eq("")

      expect(data[3]["bookmarkable_id"]).to eq(post4.id.to_s)
      expect(data[3]["bookmarkable_type"]).to eq("Post")
      expect(data[3]["link"]).to eq("")
    end
  end

  describe "category_preferences" do
    let(:component) { "category_preferences" }

    let(:subsubcategory) do
      Fabricate(
        :category_with_definition,
        parent_category_id: subcategory.id,
        name: "User Archive Subcategory",
      )
    end
    let(:announcements) { Fabricate(:category_with_definition, name: "Announcements") }
    let(:deleted_category) { Fabricate(:category, name: "Deleted Category") }
    let(:secure_category_group) { Fabricate(:group) }
    let(:secure_category) do
      Fabricate(:private_category, group: secure_category_group, name: "Super Secret Category")
    end

    let(:reset_at) { DateTime.parse("2017-03-01 12:00") }

    before do
      SiteSetting.max_category_nesting = 3

      # TopicsController#reset-new?category_id=&include_subcategories=true
      category_ids = [subcategory.id, subsubcategory.id]
      category_ids.each do |category_id|
        user
          .category_users
          .where(category_id: category_id)
          .first_or_initialize
          .update!(last_seen_at: reset_at, notification_level: NotificationLevels.all[:regular])
      end

      # Set Watching First Post on announcements, Tracking on subcategory, Muted on deleted, nothing on subsubcategory
      CategoryUser.set_notification_level_for_category(
        user,
        NotificationLevels.all[:watching_first_post],
        announcements.id,
      )
      CategoryUser.set_notification_level_for_category(
        user,
        NotificationLevels.all[:tracking],
        subcategory.id,
      )
      CategoryUser.set_notification_level_for_category(
        user,
        NotificationLevels.all[:muted],
        deleted_category.id,
      )

      deleted_category.destroy!
    end

    it "correctly exports the CategoryUser table, excluding deleted categories" do
      data, _csv_out = make_component_csv

      expect(data.find { |r| r["category_id"] == category.id.to_s }).to be_nil
      expect(data.find { |r| r["category_id"] == deleted_category.id.to_s }).to be_nil
      expect(data.length).to eq(3)
      data.sort! { |a, b| a["category_id"].to_i <=> b["category_id"].to_i }

      expect(data[0][:category_id]).to eq(subcategory.id.to_s)
      expect(data[0][:notification_level].to_s).to eq("tracking")
      expect(DateTime.parse(data[0][:dismiss_new_timestamp])).to eq(reset_at)

      expect(data[1][:category_id]).to eq(subsubcategory.id.to_s)
      expect(data[1][:category_names]).to eq(
        "#{category.name}|#{subcategory.name}|#{subsubcategory.name}",
      )
      expect(data[1][:notification_level]).to eq("regular")
      expect(DateTime.parse(data[1][:dismiss_new_timestamp])).to eq(reset_at)

      expect(data[2][:category_id]).to eq(announcements.id.to_s)
      expect(data[2][:category_names]).to eq(announcements.name)
      expect(data[2][:notification_level]).to eq("watching_first_post")
      expect(data[2][:dismiss_new_timestamp]).to eq("")
    end

    it "does not include any secure categories the user does not have access to, even if the user has a CategoryUser record" do
      CategoryUser.set_notification_level_for_category(
        user,
        NotificationLevels.all[:muted],
        secure_category.id,
      )
      data, _csv_out = make_component_csv

      expect(data.any? { |r| r["category_id"] == secure_category.id.to_s }).to eq(false)
      expect(data.length).to eq(3)
    end

    it "does include secure categories that the user has access to" do
      CategoryUser.set_notification_level_for_category(
        user,
        NotificationLevels.all[:muted],
        secure_category.id,
      )
      GroupUser.create!(user: user, group: secure_category_group)
      data, _csv_out = make_component_csv

      expect(data.any? { |r| r["category_id"] == secure_category.id.to_s }).to eq(true)
      expect(data.length).to eq(4)
    end
  end

  describe "flags" do
    let(:component) { "flags" }
    let(:other_post) { Fabricate(:post, user: admin) }
    let(:post3) { Fabricate(:post) }
    let(:post4) { Fabricate(:post) }

    it "correctly exports flags" do
      result0 = PostActionCreator.notify_moderators(user, other_post, "helping out the admins")
      PostActionCreator.spam(user, post3)
      PostActionDestroyer.destroy(user, post3, :spam)
      PostActionCreator.inappropriate(user, post3)

      result3 = PostActionCreator.off_topic(user, post4)
      result3.reviewable.perform(admin, :agree_and_keep)

      data, _csv_out = make_component_csv
      expect(data.length).to eq(4)
      data.sort_by! { |row| row["post_id"].to_i }

      expect(data[0]["post_id"]).to eq(other_post.id.to_s)
      expect(data[0]["flag_type"]).to eq("notify_moderators")
      expect(data[0]["related_post_id"]).to eq(result0.post_action.related_post_id.to_s)

      expect(data[1]["flag_type"]).to eq("spam")
      expect(data[2]["flag_type"]).to eq("inappropriate")
      expect(data[1]["deleted_at"]).to_not be_empty
      expect(data[1]["deleted_by"]).to eq("self")
      expect(data[2]["deleted_at"]).to be_empty

      expect(data[3]["post_id"]).to eq(post4.id.to_s)
      expect(data[3]["flag_type"]).to eq("off_topic")
      expect(data[3]["deleted_at"]).to be_empty
    end
  end

  describe "likes" do
    let(:component) { "likes" }
    let(:other_post) { Fabricate(:post, user: admin) }
    let(:post3) { Fabricate(:post) }

    it "correctly exports likes" do
      PostActionCreator.like(user, other_post)
      PostActionCreator.like(user, post3)
      PostActionCreator.like(admin, post3)
      PostActionDestroyer.destroy(user, post3, :like)
      post3.destroy!

      data, _csv_out = make_component_csv
      expect(data.length).to eq(2)
      data.sort_by! { |row| row["post_id"].to_i }

      expect(data[0]["post_id"]).to eq(other_post.id.to_s)
      expect(data[1]["post_id"]).to eq(post3.id.to_s)
      expect(data[1]["deleted_at"]).to_not be_empty
      expect(data[1]["deleted_by"]).to eq("self")
    end
  end

  describe "queued posts" do
    let(:component) { "queued_posts" }
    let(:reviewable_post) do
      Fabricate(:reviewable_queued_post, topic: topic, target_created_by: user)
    end
    let(:reviewable_topic) do
      Fabricate(:reviewable_queued_post_topic, category: category, target_created_by: user)
    end

    it "correctly exports queued posts" do
      SiteSetting.tagging_enabled = true

      reviewable_post.perform(admin, :reject_post)
      reviewable_topic.payload["tags"] = ["example_tag"]
      result = reviewable_topic.perform(admin, :approve_post)
      expect(result.success?).to eq(true)

      data, csv_out = make_component_csv
      expect(data.length).to eq(2)
      expect(csv_out).to_not match(admin.username)

      approved = data.find { |el| el["verdict"] === "approved" }
      rejected = data.find { |el| el["verdict"] === "rejected" }

      expect(approved["other_json"]).to match("example_tag")
      expect(rejected["post_raw"]).to eq("hello world post contents.")
      expect(rejected["other_json"]).to match("reply_to_post_number")
    end
  end

  describe "visits" do
    let(:component) { "visits" }

    it "correctly exports the UserVisit table" do
      freeze_time "2017-03-01 12:00"

      UserVisit.create(
        user_id: user.id,
        visited_at: 1.minute.ago,
        posts_read: 1,
        mobile: false,
        time_read: 10,
      )
      UserVisit.create(
        user_id: user.id,
        visited_at: 2.days.ago,
        posts_read: 2,
        mobile: false,
        time_read: 20,
      )
      UserVisit.create(
        user_id: user.id,
        visited_at: 1.week.ago,
        posts_read: 3,
        mobile: true,
        time_read: 30,
      )
      UserVisit.create(
        user_id: user.id,
        visited_at: 1.year.ago,
        posts_read: 4,
        mobile: false,
        time_read: 40,
      )
      UserVisit.create(
        user_id: user2.id,
        visited_at: 1.minute.ago,
        posts_read: 1,
        mobile: false,
        time_read: 50,
      )

      data, _csv_out = make_component_csv

      # user2's data is not mixed in
      expect(data.length).to eq(4)
      expect(data.find { |r| r["time_read"] == 50 }).to be_nil

      expect(data[0]["visited_at"]).to eq("2016-03-01")
      expect(data[0]["posts_read"]).to eq("4")
      expect(data[0]["time_read"]).to eq("40")
      expect(data[1]["mobile"]).to eq("true")
      expect(data[3]["visited_at"]).to eq("2017-03-01")
    end
  end
end
