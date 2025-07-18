# frozen_string_literal: true

require "rails_helper"

describe DiscourseDataExplorer::ReportGenerator do
  fab!(:user)
  fab!(:unauthorised_user) { Fabricate(:user) }
  fab!(:unauthorised_group) { Fabricate(:group) }
  fab!(:group) { Fabricate(:group, users: [user]) }

  fab!(:query) { DiscourseDataExplorer::Query.find(-1) }

  let(:query_params) { [%w[from_days_ago 0], %w[duration_days 15]] }

  before do
    SiteSetting.data_explorer_enabled = true
    SiteSetting.authorized_extensions = "csv"
  end

  describe ".generate" do
    it "returns [] if the recipient is not in query group" do
      Fabricate(:query_group, query: query, group: group)
      result =
        described_class.generate(
          query.id,
          query_params,
          [unauthorised_user.username, unauthorised_group.name],
        )

      expect(result).to eq []
    end

    it "returns a list of pms for authorised users" do
      SiteSetting.personal_message_enabled_groups = group.id
      DiscourseDataExplorer::ResultToMarkdown.expects(:convert).returns("le table")
      freeze_time

      result = described_class.generate(query.id, query_params, [user.username])

      expect(result).to eq(
        [
          {
            "title" =>
              I18n.t(
                "data_explorer.report_generator.private_message.title",
                query_name: query.name,
              ),
            "target_usernames" => [user.username],
            "raw" =>
              I18n.t(
                "data_explorer.report_generator.private_message.body",
                recipient_name: user.username,
                query_name: query.name,
                table: "le table",
                base_url: Discourse.base_url,
                query_id: query.id,
                created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
                timezone: Time.zone.name,
              ),
          },
        ],
      )
    end

    it "still returns a list of pms if a group or user does not exist" do
      Fabricate(:query_group, query: query, group: group)

      SiteSetting.personal_message_enabled_groups = group.id
      DiscourseDataExplorer::ResultToMarkdown.expects(:convert).returns("le table")
      freeze_time

      result = described_class.generate(query.id, query_params, [group.name, "non-existent-group"])
      expect(result).to eq(
        [
          {
            "title" =>
              I18n.t(
                "data_explorer.report_generator.private_message.title",
                query_name: query.name,
              ),
            "target_group_names" => [group.name],
            "raw" =>
              I18n.t(
                "data_explorer.report_generator.private_message.body",
                recipient_name: group.name,
                query_name: query.name,
                table: "le table",
                base_url: Discourse.base_url,
                query_id: query.id,
                created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
                timezone: Time.zone.name,
              ),
          },
        ],
      )
    end

    it "works with email recipients" do
      DiscourseDataExplorer::ResultToMarkdown.expects(:convert).returns("le table")
      freeze_time

      email = "john@doe.com"
      result = described_class.generate(query.id, query_params, [email])

      expect(result).to eq(
        [
          {
            "title" =>
              I18n.t(
                "data_explorer.report_generator.private_message.title",
                query_name: query.name,
              ),
            "target_emails" => [email],
            "raw" =>
              I18n.t(
                "data_explorer.report_generator.private_message.body",
                recipient_name: email,
                query_name: query.name,
                table: "le table",
                base_url: Discourse.base_url,
                query_id: query.id,
                created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
                timezone: Time.zone.name,
              ),
          },
        ],
      )
    end

    it "works with duplicate recipients" do
      DiscourseDataExplorer::ResultToMarkdown.expects(:convert).returns("le table")
      freeze_time

      result = described_class.generate(query.id, query_params, [user.username, user.username])

      expect(result).to eq(
        [
          {
            "title" =>
              I18n.t(
                "data_explorer.report_generator.private_message.title",
                query_name: query.name,
              ),
            "target_usernames" => [user.username],
            "raw" =>
              I18n.t(
                "data_explorer.report_generator.private_message.body",
                recipient_name: user.username,
                query_name: query.name,
                table: "le table",
                base_url: Discourse.base_url,
                query_id: query.id,
                created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
                timezone: Time.zone.name,
              ),
          },
        ],
      )
    end

    it "works with multiple recipient types" do
      Fabricate(:query_group, query: query, group: group)
      DiscourseDataExplorer::ResultToMarkdown.expects(:convert).returns("le table")

      result =
        described_class.generate(
          query.id,
          query_params,
          [group.name, user.username, "john@doe.com"],
        )

      expect(result.length).to eq(3)
      expect(result[0]["target_group_names"]).to eq([group.name])
      expect(result[1]["target_usernames"]).to eq([user.username])
      expect(result[2]["target_emails"]).to eq(["john@doe.com"])
    end

    describe "with users_from_group" do
      fab!(:valid_group) { Fabricate(:group, users: [user]) }
      fab!(:invalid_group) { Fabricate(:group, users: []) }

      describe "when true" do
        let(:opts) { { users_from_group: true } }

        it "does not work when no query groups are set" do
          result = described_class.generate(query.id, query_params, [group.name], opts)
          expect(result).to eq []
        end

        it "works when user is a member of automation group and query group" do
          Fabricate(:query_group, query: query, group: valid_group)
          result = described_class.generate(query.id, query_params, [group.name], opts)

          expect(result.length).to eq(1)
          expect(result[0]["target_usernames"]).to eq([user.username])
        end

        it "does not work when user is a member of automation group but not query group" do
          Fabricate(:query_group, query: query, group: invalid_group)
          result = described_class.generate(query.id, query_params, [group.name], opts)

          expect(result).to eq []
        end

        it "works when user has access to one group in query groups" do
          Fabricate(:query_group, query: query, group: valid_group)
          Fabricate(:query_group, query: query, group: invalid_group)

          result = described_class.generate(query.id, query_params, [group.name], opts)

          expect(result.length).to eq(1)
          expect(result[0]["target_usernames"]).to eq([user.username])
        end
      end

      describe "when false" do
        let(:opts) { { users_from_group: false } }

        it "works when group has query access" do
          Fabricate(:query_group, query: query, group: group)
          result = described_class.generate(query.id, query_params, [group.name], opts)

          expect(result.length).to eq(1)
          expect(result[0]["target_group_names"]).to eq([group.name])
        end

        it "doesn't work when group doesn't have query access" do
          result = described_class.generate(query.id, query_params, [group.name], opts)

          expect(result).to eq []
        end
      end
    end

    it "works with attached csv file" do
      SiteSetting.personal_message_enabled_groups = group.id
      DiscourseDataExplorer::ResultToMarkdown.expects(:convert).returns("le table")
      freeze_time

      result =
        described_class.generate(query.id, query_params, [user.username], { attach_csv: true })

      filename =
        "#{query.slug}@#{Slug.for(Discourse.current_hostname, "discourse")}-#{Date.today}.dcqresult.csv"

      expect(result[0]["raw"]).to eq(
        I18n.t(
          "data_explorer.report_generator.private_message.body",
          recipient_name: user.username,
          query_name: query.name,
          table: "le table",
          base_url: Discourse.base_url,
          query_id: query.id,
          created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
          timezone: Time.zone.name,
        ) + "\n\n" +
          I18n.t(
            "data_explorer.report_generator.upload_appendix",
            filename: filename,
            short_url: Upload.find_by(original_filename: filename).short_url,
          ),
      )
    end
  end

  describe ".generate_post" do
    it "works without attached csv file" do
      DiscourseDataExplorer::ResultToMarkdown.expects(:convert).returns("le table")
      freeze_time

      result = described_class.generate_post(query.id, query_params)

      expect(result["raw"]).to eq(
        I18n.t(
          "data_explorer.report_generator.post.body",
          query_name: query.name,
          table: "le table",
          base_url: Discourse.base_url,
          query_id: query.id,
          created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
          timezone: Time.zone.name,
        ),
      )
    end

    it "works with attached csv file" do
      DiscourseDataExplorer::ResultToMarkdown.expects(:convert).returns("le table")
      freeze_time

      result = described_class.generate_post(query.id, query_params, { attach_csv: true })

      filename =
        "#{query.slug}@#{Slug.for(Discourse.current_hostname, "discourse")}-#{Date.today}.dcqresult.csv"

      expect(result["raw"]).to eq(
        I18n.t(
          "data_explorer.report_generator.post.body",
          query_name: query.name,
          table: "le table",
          base_url: Discourse.base_url,
          query_id: query.id,
          created_at: Time.zone.now.strftime("%Y-%m-%d at %H:%M:%S"),
          timezone: Time.zone.name,
        ) + "\n\n" +
          I18n.t(
            "data_explorer.report_generator.upload_appendix",
            filename: filename,
            short_url: Upload.find_by(original_filename: filename).short_url,
          ),
      )
    end
  end

  describe ".params_to_hash" do
    context "when passing nothing" do
      let(:query_params) { "[]" }

      it { expect(described_class.params_to_hash(query_params)).to eq({}) }
    end

    context "when passing an array of arrays" do
      let(:query_params) { '[["foo", 1], ["bar", 2]]' }

      it { expect(described_class.params_to_hash(query_params)).to eq({ "foo" => 1, "bar" => 2 }) }
    end

    context "when passing an array of hashes" do
      let(:query_params) { '[{ "key": "foo", "value": 1 }, { "key": "bar", "value": 2 }]' }

      it { expect(described_class.params_to_hash(query_params)).to eq({ "foo" => 1, "bar" => 2 }) }
    end
  end
end
