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

    context "when changing the primary group flag" do
      fab!(:member, :user)

      before do
        SiteSetting.moderators_manage_groups = true
        group.add(member)
      end

      it "does not let a moderator change it while another staff account is a member" do
        [admin, Fabricate(:moderator)].each do |staff_user|
          staff_group = Fabricate(:group)
          staff_group.add(member)
          staff_group.add(staff_user)

          expect {
            described_class.update(moderator.guardian, staff_group, { "primary_group" => true })
          }.to raise_error(Discourse::InvalidAccess)

          expect(staff_group.reload.primary_group).to eq(false)
          expect(staff_user.reload.primary_group_id).to eq(nil)
          expect(member.reload.primary_group_id).to eq(nil)
        end
      end

      it "does not let a moderator clear it while another staff account is a member" do
        group.update!(primary_group: true)
        group.add(admin)
        expect(admin.reload.primary_group_id).to eq(group.id)

        expect {
          described_class.update(moderator.guardian, group, { "primary_group" => "false" })
        }.to raise_error(Discourse::InvalidAccess)

        expect(group.reload.primary_group).to eq(true)
        expect(admin.reload.primary_group_id).to eq(group.id)
      end

      it "lets an admin clear it while staff accounts are members" do
        group.update!(primary_group: true)
        group.add(moderator)

        described_class.update(admin.guardian, group, { "primary_group" => "false" })

        expect(group.reload.primary_group).to eq(false)
        expect(moderator.reload.primary_group_id).to eq(nil)
      end

      it "lets a moderator save other settings when the flag is unchanged" do
        group.add(admin)

        described_class.update(
          moderator.guardian,
          group,
          { "primary_group" => false, "bio_raw" => "We write docs" },
        )

        expect(group.reload.bio_raw).to eq("We write docs")
      end

      it "lets a moderator change it when the only staff member is themselves" do
        group.add(moderator)

        described_class.update(moderator.guardian, group, { "primary_group" => true })

        expect(group.reload.primary_group).to eq(true)
        expect(member.reload.primary_group_id).to eq(group.id)
        expect(moderator.reload.primary_group_id).to eq(group.id)
      end

      it "lets an admin change it while staff accounts are members" do
        group.add(moderator)

        described_class.update(admin.guardian, group, { "primary_group" => true })

        expect(moderator.reload.primary_group_id).to eq(group.id)
      end
    end

    context "when changing the title" do
      before { SiteSetting.moderators_manage_groups = true }

      it "does not let a moderator change it while another staff account would receive it" do
        blank_title_group = Fabricate(:group)
        blank_title_group.add(admin)
        titled_group = Fabricate(:group, title: "Docs team")
        peer_moderator = Fabricate(:moderator)
        titled_group.add(peer_moderator)
        expect(peer_moderator.reload.title).to eq("Docs team")

        changes = [[blank_title_group, "Writers"], [titled_group, "Writers"], [titled_group, ""]]
        changes.each do |staff_group, new_title|
          expect {
            described_class.update(moderator.guardian, staff_group, { "title" => new_title })
          }.to raise_error(Discourse::InvalidAccess)
        end

        expect(blank_title_group.reload.title).to eq(nil)
        expect(titled_group.reload.title).to eq("Docs team")
        expect(admin.reload.title).to eq(nil)
        expect(peer_moderator.reload.title).to eq("Docs team")
      end

      it "lets a moderator change it when other staff accounts keep their own title" do
        admin.update!(title: "Site admin")
        group.add(admin)
        group.add(user)

        described_class.update(moderator.guardian, group, { "title" => "Writers" })

        expect(group.reload.title).to eq("Writers")
        expect(user.reload.title).to eq("Writers")
        expect(admin.reload.title).to eq("Site admin")

        titled_group = Fabricate(:group, title: "Docs team")
        peer_moderator = Fabricate(:moderator)
        titled_group.add(peer_moderator)
        peer_moderator.update_columns(title: nil)

        described_class.update(moderator.guardian, titled_group, { "title" => "" })

        expect(titled_group.reload.title).to be_blank
      end

      it "lets a moderator change it when the only staff member is themselves" do
        group.add(moderator)

        described_class.update(moderator.guardian, group, { "title" => "Writers" })

        expect(moderator.reload.title).to eq("Writers")
      end

      it "lets a moderator save other settings when the title is unchanged" do
        group.update!(title: "Docs team")
        group.add(admin)
        admin.update_columns(title: nil)

        described_class.update(
          moderator.guardian,
          group,
          { "title" => "Docs team", "bio_raw" => "We write docs" },
        )

        expect(group.reload.bio_raw).to eq("We write docs")
      end

      it "lets an admin change it while staff accounts would receive it" do
        group.add(moderator)

        described_class.update(admin.guardian, group, { "title" => "Writers" })

        expect(moderator.reload.title).to eq("Writers")
      end
    end

    context "when the group adds members by email domain" do
      fab!(:domain_admin) { Fabricate(:admin, email: "boss@staff.test") }

      before { SiteSetting.moderators_manage_groups = true }

      it "does not let a moderator save settings that would change another staff account joining by domain" do
        category = Fabricate(:category)
        settings = [
          { "primary_group" => true },
          { "title" => "Docs team" },
          { "grant_trust_level" => 3 },
          { "watching_category_ids" => [category.id] },
        ]

        settings.each do |setting|
          domain_group = Fabricate(:group)

          expect {
            described_class.update(
              moderator.guardian,
              domain_group,
              { "automatic_membership_email_domains" => "staff.test", **setting },
            )
          }.to raise_error(Discourse::InvalidAccess)

          expect(domain_group.reload.automatic_membership_email_domains).to eq(nil)
        end
      end

      it "does not let a moderator add a domain or a setting when the other is already there" do
        titled_group = Fabricate(:group, title: "Docs team")
        defaults_group = Fabricate(:group)
        GroupTagNotificationDefault.create!(
          group: defaults_group,
          tag: Fabricate(:tag),
          notification_level: NotificationLevels.all[:watching],
        )
        domain_group = Fabricate(:group, automatic_membership_email_domains: "staff.test")

        [titled_group, defaults_group].each do |configured_group|
          expect {
            described_class.update(
              moderator.guardian,
              configured_group,
              { "automatic_membership_email_domains" => "@Staff.test" },
            )
          }.to raise_error(Discourse::InvalidAccess)
          expect(configured_group.reload.automatic_membership_email_domains).to eq(nil)
        end

        expect {
          described_class.update(moderator.guardian, domain_group, { "title" => "Docs team" })
        }.to raise_error(Discourse::InvalidAccess)
        expect(domain_group.reload.title).to eq(nil)
      end

      it "lets a moderator add a domain to a group whose settings leave joining accounts alone" do
        described_class.update(
          moderator.guardian,
          group,
          { "automatic_membership_email_domains" => "staff.test" },
        )

        expect(group.reload.automatic_membership_email_domains).to eq("staff.test")
      end

      it "lets a moderator save it when only regular users and themselves would join" do
        moderator.primary_email.update!(email: "mod@crew.test")
        Fabricate(:user, email: "writer@crew.test")
        category = Fabricate(:category)

        described_class.update(
          moderator.guardian,
          group,
          {
            "automatic_membership_email_domains" => "crew.test",
            "primary_group" => true,
            "watching_category_ids" => [category.id],
          },
          update_existing_users: false,
        )

        expect(group.reload).to have_attributes(
          automatic_membership_email_domains: "crew.test",
          primary_group: true,
        )
      end

      it "lets a moderator save it when the matching staff accounts are already members" do
        group.add(domain_admin)

        described_class.update(
          moderator.guardian,
          group,
          { "automatic_membership_email_domains" => "staff.test", "grant_trust_level" => 3 },
        )

        expect(group.reload.grant_trust_level).to eq(3)
      end

      it "lets an admin save it" do
        category = Fabricate(:category)

        described_class.update(
          admin.guardian,
          group,
          {
            "automatic_membership_email_domains" => "staff.test",
            "primary_group" => true,
            "watching_category_ids" => [category.id],
          },
          update_existing_users: false,
        )

        expect(group.reload.primary_group).to eq(true)
      end
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

      it "does not apply a moderator's defaults to other staff accounts" do
        SiteSetting.moderators_manage_groups = true
        tag = Fabricate(:tag)
        other_moderator = Fabricate(:moderator)
        group.add(other_moderator)
        group.add(moderator)

        described_class.update(
          moderator.guardian,
          group,
          {
            "default_notification_level" => NotificationLevels.all[:muted],
            "watching_category_ids" => [category.id],
            "tracking_tags" => [tag.name],
          },
          update_existing_users: true,
        )

        expect(GroupUser.find_by(group:, user: other_moderator).notification_level).not_to eq(
          NotificationLevels.all[:muted],
        )
        expect(CategoryUser.where(user: other_moderator, category:)).to be_empty
        expect(TagUser.where(user: other_moderator, tag:)).to be_empty

        expect(GroupUser.find_by(group:, user: member).notification_level).to eq(
          NotificationLevels.all[:muted],
        )
        expect(CategoryUser.find_by(user: member, category:).notification_level).to eq(
          NotificationLevels.all[:watching],
        )
        expect(TagUser.find_by(user: member, tag:).notification_level).to eq(
          NotificationLevels.all[:tracking],
        )
        expect(GroupUser.find_by(group:, user: moderator).notification_level).to eq(
          NotificationLevels.all[:muted],
        )
      end

      it "keeps a staff account's existing preference when a group owner changes the default" do
        group.add(admin)
        described_class.update(
          admin.guardian,
          group,
          { "watching_category_ids" => [category.id] },
          update_existing_users: true,
        )

        described_class.update(
          owner.guardian,
          group.reload,
          { "tracking_category_ids" => [category.id] },
          update_existing_users: true,
        )

        expect(CategoryUser.find_by(user: admin, category:).notification_level).to eq(
          NotificationLevels.all[:watching],
        )
        expect(CategoryUser.find_by(user: member, category:).notification_level).to eq(
          NotificationLevels.all[:tracking],
        )
      end

      it "applies an admin's defaults to staff accounts" do
        group.add(moderator)

        described_class.update(
          admin.guardian,
          group,
          { "watching_category_ids" => [category.id] },
          update_existing_users: true,
        )

        expect(CategoryUser.find_by(user: moderator, category:).notification_level).to eq(
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
