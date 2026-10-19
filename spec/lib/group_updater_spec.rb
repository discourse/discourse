# frozen_string_literal: true

describe GroupUpdater do
  fab!(:admin)
  fab!(:moderator)
  fab!(:owner, :user)
  fab!(:user)
  fab!(:group)

  before { group.add_owner(owner) }

  describe ".permitted_names" do
    it "lets a group owner change the profile but not staff-only settings" do
      names = described_class.permitted_names(owner.guardian, group:)

      expect(names).to include("bio_raw", "full_name", "public_admission")
      expect(names).not_to include("name", "title", "visibility_level", "smtp_server")
    end

    it "lets staff change visibility and group identity" do
      names = described_class.permitted_names(moderator.guardian, group:)

      expect(names).to include("name", "title", "visibility_level", "members_visibility_level")
      expect(names).not_to include("smtp_server", "email_password")
    end

    it "lets an admin change email settings" do
      expect(described_class.permitted_names(admin.guardian, group:)).to include(
        "smtp_server",
        "email_password",
        "automatic_membership_email_domains",
      )
    end

    it "drops settings that do not apply to an automatic group" do
      automatic = Group.find(Group::AUTO_GROUPS[:trust_level_1])
      names = described_class.permitted_names(admin.guardian, group: automatic)

      expect(names).not_to include("name", "public_admission", "automatic_membership_email_domains")
      expect(names).to include("bio_raw", "visibility_level")
    end
  end

  describe ".update" do
    it "accepts registered custom fields without allowing other nested fields" do
      Plugin::Instance.new.register_editable_group_custom_field(:editable)

      described_class.update(
        admin.guardian,
        group,
        { custom_fields: { editable: "yes", private: "no" } },
      )

      expect(group.reload.custom_fields).to eq("editable" => "yes")
    ensure
      DiscoursePluginRegistry.reset!
    end

    it "filters staff-only settings when called directly by an owner" do
      original_name = group.name
      described_class.update(
        owner.guardian,
        group,
        { bio_raw: "Allowed", name: "forbidden", grant_trust_level: 4 },
      )

      expect(group.reload.bio_raw).to eq("Allowed")
      expect(group.name).to eq(original_name)
      expect(group.grant_trust_level).to be_nil
    end

    it "filters admin-only email settings when called directly by a moderator" do
      group.add_owner(moderator)
      described_class.update(
        moderator.guardian,
        group,
        { bio_raw: "Allowed", email_password: "secret" },
      )

      expect(group.reload.bio_raw).to eq("Allowed")
      expect(group.email_password).to be_blank
    end

    it "updates the group and logs the change" do
      expect(described_class.update(owner.guardian, group, { "bio_raw" => "We write docs" })).to eq(
        true,
      )

      expect(group.reload.bio_raw).to eq("We write docs")
      expect(
        GroupHistory.exists?(group:, action: GroupHistory.actions[:change_group_setting]),
      ).to eq(true)
    end

    it "refuses a user who cannot edit the group" do
      expect {
        described_class.update(user.guardian, group, { "bio_raw" => "nope" })
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "returns false and keeps the model errors when the group is invalid" do
      expect(described_class.update(admin.guardian, group, { "name" => "" })).to eq(false)
      expect(group.errors).to be_present
    end

    it "clears the SMTP credentials when SMTP is turned off" do
      smtp_group = Fabricate(:smtp_group)

      described_class.update(admin.guardian, smtp_group, { "smtp_enabled" => false })

      smtp_group.reload
      expect(smtp_group.smtp_enabled).to eq(false)
      expect(smtp_group.smtp_server).to eq(nil)
      expect(smtp_group.smtp_port).to eq(nil)
      expect(smtp_group.email_username).to eq(nil)
      expect(smtp_group.email_password).to eq(nil)
    end

    it "accepts the string form of smtp_enabled sent by the HTTP endpoint" do
      smtp_group = Fabricate(:smtp_group)

      described_class.update(admin.guardian, smtp_group, { "smtp_enabled" => "false" })

      expect(smtp_group.reload.smtp_server).to eq(nil)
    end

    context "with notification defaults" do
      fab!(:category)
      fab!(:member, :user)

      before { group.add(member) }

      it "asks for confirmation when existing members would be changed" do
        described_class.update(
          admin.guardian,
          group,
          { "watching_category_ids" => [category.id] },
          update_existing_users: false,
        )

        expect {
          described_class.update(
            admin.guardian,
            group,
            { "tracking_category_ids" => [category.id] },
          )
        }.to raise_error(GroupUpdater::ExistingUsersConfirmationRequired) { |error|
          expect(error.user_count).to eq(2) # the owner and the member
        }
      end

      it "leaves existing members alone when confirmation is declined" do
        described_class.update(
          admin.guardian,
          group,
          { "watching_category_ids" => [category.id] },
          update_existing_users: false,
        )

        expect(CategoryUser.where(user: member, category:)).to be_empty
        expect(group.reload.group_category_notification_defaults.pluck(:category_id)).to eq(
          [category.id],
        )
      end

      it "applies the default to existing members when confirmed" do
        described_class.update(
          admin.guardian,
          group,
          { "watching_category_ids" => [category.id] },
          update_existing_users: true,
        )

        expect(CategoryUser.find_by(user: member, category:).notification_level).to eq(
          NotificationLevels.all[:watching],
        )
      end

      it "does not ask for confirmation when nothing changes for existing members" do
        expect(described_class.update(admin.guardian, group, { "bio_raw" => "unrelated" })).to eq(
          true,
        )
      end

      it "clears only explicitly emptied defaults and leaves other levels untouched" do
        tag = Fabricate(:tag)
        described_class.update(
          admin.guardian,
          group,
          { watching_category_ids: [category.id], tracking_tags: [tag.name] },
          update_existing_users: true,
        )

        described_class.update(
          admin.guardian,
          group.reload,
          { watching_category_ids: [] },
          update_existing_users: true,
        )

        expect(group.reload.group_category_notification_defaults).to be_empty
        expect(CategoryUser.where(user: member, category:)).to be_empty
        expect(group.group_tag_notification_defaults.pluck(:tag_id)).to eq([tag.id])
        expect(TagUser.find_by!(user: member, tag:).notification_level).to eq(
          NotificationLevels.all[:tracking],
        )

        described_class.update(
          admin.guardian,
          group,
          { tracking_tags: [] },
          update_existing_users: true,
        )

        expect(group.reload.group_tag_notification_defaults).to be_empty
        expect(TagUser.where(user: member, tag:)).to be_empty
      end

      it "only lets an admin change notification defaults on an automatic group" do
        automatic = Group.find(Group::AUTO_GROUPS[:trust_level_1])

        expect(
          described_class.permitted_names(moderator.guardian, group: automatic),
        ).not_to include("watching_category_ids")
        expect(described_class.permitted_names(admin.guardian, group: automatic)).to include(
          "watching_category_ids",
        )
      end

      it "requires confirmation for a synonym and preserves members when applying it is declined" do
        tag = Fabricate(:tag)
        synonym = Fabricate(:tag, target_tag: tag)
        group.update!(tracking_tags: [tag.name])
        TagUser.change(member.id, tag.id, NotificationLevels.all[:tracking])

        expect {
          described_class.update(
            admin.guardian,
            group.reload,
            { watching_tags: [synonym.name.upcase] },
          )
        }.to raise_error(GroupUpdater::ExistingUsersConfirmationRequired)
        expect(group.reload.group_tag_notification_defaults.pluck(:notification_level)).to eq(
          [NotificationLevels.all[:tracking]],
        )

        described_class.update(
          admin.guardian,
          group,
          { watching_tags: [synonym.name.upcase] },
          update_existing_users: false,
        )

        expect(
          group.reload.group_tag_notification_defaults.pluck(:tag_id, :notification_level),
        ).to eq([[tag.id, NotificationLevels.all[:watching]]])
        expect(TagUser.find_by!(user: member, tag:).notification_level).to eq(
          NotificationLevels.all[:tracking],
        )
      end
    end
  end
end
