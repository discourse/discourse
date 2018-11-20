# custom importer for www.sfn.org, feel free to borrow ideas

require "csv"
require "mysql2"

require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Sfn < ImportScripts::Base

  BATCH_SIZE = 100_000
  MIN_CREATED_AT = "2003-11-01"

  def initialize
    super
  end

  def execute
    load_external_users
    import_users
    # import_categories
    import_topics
    import_posts
  end

  def load_external_users
    puts "", "loading external users..."

    @personify_id_to_contact_key = {}

    contacts = mysql_query <<-SQL
      SELECT ContactKey  AS "contact_key",
             PersonifyID AS "personify_id"
        FROM Contact
    SQL

    contacts.each do |contact|
      personify_id = contact["personify_id"].split(",").first
      @personify_id_to_contact_key[personify_id] = contact["contact_key"]
    end

    @external_users = {}

    CSV.foreach("/Users/zogstrip/Desktop/sfn.csv", col_sep: ";") do |row|
      next unless @personify_id_to_contact_key.include?(row[0])

      id = @personify_id_to_contact_key[row[0]]
      full_name = [row[1].strip, row[2].strip, row[3].strip].join(" ").strip

      @external_users[id] = { email: row[4], full_name: full_name }
    end
  end

  def import_users
    puts "", "importing users..."

    user_count = mysql_query <<-SQL
      SELECT COUNT(ContactKey) AS "count" FROM Contact
    SQL

    user_count = user_count.first["count"]

    batches(BATCH_SIZE) do |offset|
      users = mysql_query <<-SQL
           SELECT c.ContactKey   AS "id",
                  c.Bio          AS "bio",
                  c.ProfileImage AS "avatar",
                  es.EmailAddr_  AS "email",
                  es.FullName_   AS "full_name",
                  GREATEST('#{MIN_CREATED_AT}', COALESCE(cm.InvitedOn, '#{MIN_CREATED_AT}')) AS "created_at"
             FROM Contact c
        LEFT JOIN EgroupSubscription es ON es.ContactKey = c.ContactKey
        LEFT JOIN CommunityMember cm    ON cm.ContactKey = c.ContactKey
         GROUP BY c.ContactKey
         ORDER BY cm.InvitedOn
            LIMIT #{BATCH_SIZE}
           OFFSET #{offset}
      SQL

      break if users.size < 1
      next if all_records_exist? :users, users.map { |u| u["id"].to_i }

      create_users(users, total: user_count, offset: offset) do |user|
        external_user = @external_users[user["id"]]
        email = user["email"].presence || external_user.try(:[], :email)
        full_name = user["full_name"].presence || external_user.try(:[], :full_name)
        bio = (user["bio"] || "")[0..250]

        next if email.blank?

        {
          id: user["id"],
          email: email,
          name: full_name,
          username: email.split("@")[0],
          bio_raw: bio,
          created_at: user["created_at"],
          post_create_action: proc do |newuser|
            next if user["avatar"].blank?

            avatar = Tempfile.new("sfn-avatar")
            avatar.write(user["avatar"].encode("ASCII-8BIT").force_encoding("UTF-8"))
            avatar.rewind

            upload = UploadCreator.new(avatar, "avatar.jpg").create_for(newuser.id)
            if upload.persisted?
              newuser.create_user_avatar
              newuser.user_avatar.update(custom_upload_id: upload.id)
              newuser.update(uploaded_avatar_id: upload.id)
            end

            avatar.try(:close!) rescue nil
          end
        }
      end
    end
  end

  # NEW_CATEGORIES = [
  #   "Abstract Topic Matching Forum",
  #   "Animals in Research",
  #   "Brain Awareness & Teaching",
  #   "Career Advice",
  #   "Career Paths",
  #   "Diversity",
  #   "Early Career Policy Advocates",
  #   "LATP Associates",
  #   "LATP Fellows",
  #   "Mid & Advanced Career",
  #   "Neurobiology of Disease Workshop",
  #   "Neuronline Champions",
  #   "Neuroscience 2015",
  #   "Neuroscience Scholars Program",
  #   "NSP Associates",
  #   "NSP Fellows",
  #   "Outreach",
  #   "Postdocs & Early Career",
  #   "Program Committee",
  #   "Program Development",
  #   "Roommate Matching Forum",
  #   "Scientific Research",
  #   "Students",
  # ]

  # EgroupKey => New Category Name
  CATEGORY_MAPPING = {
    "{DE10E4F4-621A-48BF-9B45-05D9F774A590}" => 52, # "Abstract Topic Matching Forum",
    "{3FFC1217-1576-4D38-BB81-D6CADC7FB793}" => 66, # "Animals in Research",
    "{9362BB21-BF6C-4E55-A3E0-18CD5D9F3323}" => 67, # "Brain Awareness & Teaching",
    "{3AC01B09-A21F-4166-95DA-0E585E271075}" => 67, # "Brain Awareness & Teaching",
    "{C249728D-8C9E-4138-AA49-D02467C28EAD}" => 42, # "Career Advice",
    "{01570B85-0124-478F-A8B9-B028BD1B1F2F}" => 43, # "Career Paths",
    "{2A430528-278A-46CD-BE1A-07CFA1122919}" => 44, # "Diversity",
    "{2F211345-3C19-43C9-90B5-27BA9FCD4DB0}" => 44, # "Diversity",
    "{8092297D-8DF4-404A-8BEB-4D5D0DC6A191}" => 56, # "Early Career Policy Advocates",
    "{8CB58762-D562-448C-9AF1-8DAE6C482C9B}" => 61, # "LATP Associates",
    "{CDF80A92-925A-46DD-A867-8558FA72D016}" => 60, # "LATP Fellows",
    "{E71E237B-7C23-4596-AECA-655BD8ED50DB}" => 51, # "Mid & Advanced Career",
    "{1D674C38-17CB-4C48-826A-D465AC3F8948}" => 55, # "Neurobiology of Disease Workshop",
    "{80C5835E-974E-4D44-BA01-C2C4F8BA91D7}" => 65, # "Neuronline Champions",
    "{3D4F885B-0037-403B-83DD-62FAA8E81DF1}" => 54, # "Neuroscience 2015",
    "{9ACC3B40-E4A3-4FFD-AADC-C8403EB6231D}" => 54, # "Neuroscience 2015",
    "{9FC30FFB-E450-4361-8844-0266C3D96868}" => 57, # "Neuroscience Scholars Program",
    "{3E78123E-87CE-435E-B4B7-7DAB1A21C541}" => 59, # "NSP Associates",
    "{12D889D3-5CFD-49D5-93E4-32AAB2CFFCDA}" => 58, # "NSP Fellows",
    "{FA86D79E-170E-4F53-8F1C-942CB3FFB19E}" => 45, # "Outreach",
    "{D7041C64-3D32-4010-B3D8-71858323CB4A}" => 45, # "Outreach",
    "{69B76913-4E23-4C80-A11E-9CDB4130722E}" => 45, # "Outreach",
    "{774878EA-96AD-49F5-9D29-105AEA488007}" => 45, # "Outreach",
    "{E6349704-FD01-41B1-9C59-68E928DD4318}" => 50, # "Postdocs & Early Career",
    "{31CF5944-2567-4E79-9730-18EEC23E5B52}" => 50, # "Postdocs & Early Career",
    "{5625C403-AFAE-4323-A470-33FC32B12B53}" => 62, # "Program Committee",
    "{8415D871-54F5-4128-B099-E5A376A6B41B}" => 47, # "Program Development",
    "{B4DF2044-47AB-4329-8BF7-0D832CAB402C}" => 53, # "Roommate Matching Forum",
    "{6A3A12B9-5C72-472F-97AC-F34983674960}" => 48, # "Scientific Research",
    "{2CF635E9-4866-451C-A4F2-E2A8A80FED54}" => 48, # "Scientific Research",
    "{CF2DDCCE-737F-499D-AFE4-E5C36F195C8B}" => 48, # "Scientific Research",
    "{282B48D7-AC1D-453E-9806-3C6CE6830EF9}" => 48, # "Scientific Research",
    "{6D750CAF-E96F-4AD1-A45B-7B74FDFF0B40}" => 48, # "Scientific Research",
    "{10AF5D45-BEB3-4F07-BE77-0BAB6910DE10}" => 48, # "Scientific Research",
    "{18D7F624-26D1-44B9-BF33-AB5C5A2AB2BF}" => 48, # "Scientific Research",
    "{6016FF4F-D834-4888-BA03-F9FE8CB1D4CC}" => 48, # "Scientific Research",
    "{B0290A37-EA39-4CB8-B6CB-3E0B7EF6D036}" => 48, # "Scientific Research",
    "{97CC60D0-B93A-43FF-BB48-366FAAEE2BAC}" => 48, # "Scientific Research",
    "{8FC9B57B-2755-4FC5-90E8-CCDB56CF2F66}" => 48, # "Scientific Research",
    "{57C8BF37-357E-4FE6-952D-906248642792}" => 48, # "Scientific Research",
    "{7B2A3B63-BC2C-4219-830C-BA1DECB33337}" => 48, # "Scientific Research",
    "{0ED1D205-0E48-48D2-B82B-3CE80C6C553F}" => 48, # "Scientific Research",
    "{10355962-D172-4294-AA8E-1BC381B67971}" => 48, # "Scientific Research",
    "{C84B0222-5232-4B94-9FB8-DDF802241171}" => 48, # "Scientific Research",
    "{9143F984-0D67-46CB-AAAF-7FE3B6335E07}" => 48, # "Scientific Research",
    "{1392DC10-37A0-46A6-9979-4568D0224C5F}" => 48, # "Scientific Research",
    "{E4891409-0F4F-4151-B550-ECE53655E231}" => 48, # "Scientific Research",
    "{9613BAC2-229B-4563-9E1C-35C31CDDCE2F}" => 49, # "Students",
  }

  def import_categories
    puts "", "importing categories..."

    create_categories(NEW_CATEGORIES) do |category|
      { id: category, name: category }
    end
  end

  def import_topics
    puts "", "importing topics..."

    topic_count = mysql_query <<-SQL
      SELECT COUNT(MessageID_) AS "count"
        FROM EgroupMessages
       WHERE ParentId_ = 0
         AND ApprovedRejectedPendingInd = "Approved"
         AND (CrosspostFromMessageKey IS NULL OR CrosspostFromMessageKey = '{00000000-0000-0000-0000-000000000000}')
    SQL

    topic_count = topic_count.first["count"]

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query <<-SQL
           SELECT MessageID_  AS "id",
                  EgroupKey   AS "category_id",
                  ContactKey  AS "user_id",
                  HdrSubject_ AS "title",
                  Body_       AS "raw",
                  CreatStamp_ AS "created_at"
             FROM EgroupMessages
            WHERE ParentId_ = 0
              AND ApprovedRejectedPendingInd = "Approved"
              AND (CrosspostFromMessageKey IS NULL OR CrosspostFromMessageKey = '{00000000-0000-0000-0000-000000000000}')
         ORDER BY CreatStamp_
            LIMIT #{BATCH_SIZE}
           OFFSET #{offset}
      SQL

      break if topics.size < 1
      next if all_records_exist? :posts, topics.map { |t| t['id'].to_i }

      create_posts(topics, total: topic_count, offset: offset) do |topic|
        next unless category_id = CATEGORY_MAPPING[topic["category_id"]]

        title = topic["title"][0..250]
        raw = cleanup_raw(topic["raw"])
        next if raw.blank?

        {
          id: topic["id"],
          category: category_id,
          user_id: user_id_from_imported_user_id(topic["user_id"]) || Discourse::SYSTEM_USER_ID,
          title: title,
          raw: raw,
          created_at: topic["created_at"],
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    posts_count = mysql_query <<-SQL
      SELECT COUNT(MessageID_) AS "count"
        FROM EgroupMessages
       WHERE ParentId_ > 0
         AND ApprovedRejectedPendingInd = "Approved"
         AND (CrosspostFromMessageKey IS NULL OR CrosspostFromMessageKey = '{00000000-0000-0000-0000-000000000000}')
    SQL

    posts_count = posts_count.first["count"]

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query <<-SQL
           SELECT MessageID_  AS "id",
                  ContactKey  AS "user_id",
                  ParentID_   AS "topic_id",
                  Body_       AS "raw",
                  CreatStamp_ AS "created_at"
             FROM EgroupMessages
            WHERE ParentId_ > 0
              AND ApprovedRejectedPendingInd = "Approved"
              AND (CrosspostFromMessageKey IS NULL OR CrosspostFromMessageKey = '{00000000-0000-0000-0000-000000000000}')
         ORDER BY CreatStamp_
            LIMIT #{BATCH_SIZE}
           OFFSET #{offset}
      SQL

      break if posts.size < 1

      next if all_records_exist? :posts, posts.map { |p| p['id'].to_i }

      create_posts(posts, total: posts_count, offset: offset) do |post|
        next unless parent = topic_lookup_from_imported_post_id(post["topic_id"])

        raw = cleanup_raw(post["raw"])
        next if raw.blank?

        {
          id: post["id"],
          topic_id: parent[:topic_id],
          user_id: user_id_from_imported_user_id(post["user_id"]) || Discourse::SYSTEM_USER_ID,
          raw: cleanup_raw(post["raw"]),
          created_at: post["created_at"],
        }
      end
    end
  end

  def cleanup_raw(raw)
    # fix some html
    raw.gsub!(/<br\s*\/?>/i, "\n")
    # remove "This message has been cross posted to the following eGroups: ..."
    raw.gsub!(/^This message has been cross posted to the following eGroups: .+\n-{3,}/i, "")
    # remove signatures
    raw.gsub!(/-{3,}.+/m, "")
    # strip leading/trailing whitespaces
    raw.strip
  end

  def mysql_query(sql)
    @client ||= Mysql2::Client.new(username: "root", database: "sfn")
    @client.query(sql)
  end

end

ImportScripts::Sfn.new.perform
