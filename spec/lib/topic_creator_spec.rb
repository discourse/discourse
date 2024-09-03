# frozen_string_literal: true

RSpec.describe TopicCreator do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:moderator)
  fab!(:admin)

  let(:valid_attrs) { Fabricate.attributes_for(:topic) }
  let(:pm_valid_attrs) do
    {
      raw: "this is a new post",
      title: "this is a new title",
      archetype: Archetype.private_message,
      target_usernames: moderator.username,
    }
  end

  let(:pm_to_email_valid_attrs) do
    {
      raw: "this is a new email",
      title: "this is a new subject",
      archetype: Archetype.private_message,
      target_emails: "moderator@example.com",
    }
  end

  describe "#create" do
    context "with topic success cases" do
      before do
        TopicCreator.any_instance.expects(:save_topic).returns(true)
        TopicCreator.any_instance.expects(:watch_topic).returns(true)
        SiteSetting.allow_duplicate_topic_titles = true
      end

      it "should be possible for an admin to create a topic" do
        expect(TopicCreator.create(admin, Guardian.new(admin), valid_attrs)).to be_valid
      end

      it "should be possible for a moderator to create a topic" do
        expect(TopicCreator.create(moderator, Guardian.new(moderator), valid_attrs)).to be_valid
      end

      it "supports custom_fields that has been registered to the DiscoursePluginRegistry" do
        opts = valid_attrs.merge(custom_fields: { import_id: "bar" })

        topic = TopicCreator.create(admin, Guardian.new(admin), opts)

        expect(topic.custom_fields["import_id"]).to eq("bar")
      end

      context "with regular user" do
        before { SiteSetting.create_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0] }

        it "should be possible for a regular user to create a topic" do
          expect(TopicCreator.create(user, Guardian.new(user), valid_attrs)).to be_valid
        end

        it "should be possible for a regular user to create a topic with blank auto_close_time" do
          expect(
            TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(auto_close_time: "")),
          ).to be_valid
        end

        it "ignores auto_close_time without raising an error" do
          topic =
            TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(auto_close_time: "24"))
          expect(topic).to be_valid
          expect(topic.public_topic_timer).to eq(nil)
        end

        it "can create a topic in a category" do
          category = Fabricate(:category, name: "Neil's Blog")
          topic =
            TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(category: category.id))
          expect(topic).to be_valid
          expect(topic.category).to eq(category)
        end

        it "ignores participant_count without raising an error" do
          topic =
            TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(participant_count: 3))
          expect(topic.participant_count).to eq(1)
        end

        it "accepts participant_count in import mode" do
          topic =
            TopicCreator.create(
              user,
              Guardian.new(user),
              valid_attrs.merge(import_mode: true, participant_count: 3),
            )
          expect(topic.participant_count).to eq(3)
        end
      end
    end

    context "with tags" do
      fab!(:tag1) { Fabricate(:tag, name: "fun") }
      fab!(:tag2) { Fabricate(:tag, name: "fun2") }
      fab!(:tag3) { Fabricate(:tag, name: "fun3") }
      fab!(:tag4) { Fabricate(:tag, name: "fun4") }
      fab!(:tag5) { Fabricate(:tag, name: "fun5") }
      fab!(:tag_group1) { Fabricate(:tag_group, tags: [tag1]) }
      fab!(:tag_group2) { Fabricate(:tag_group, tags: [tag2]) }

      before do
        SiteSetting.tagging_enabled = true
        SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
        SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      end

      context "with regular tags" do
        it "user can add tags to topic" do
          topic =
            TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(tags: [tag1.name]))
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(1)
        end
      end

      context "when assigned via matched watched words" do
        fab!(:word1) do
          Fabricate(:watched_word, action: WatchedWord.actions[:tag], replacement: tag1.name)
        end
        fab!(:word2) do
          Fabricate(:watched_word, action: WatchedWord.actions[:tag], replacement: tag2.name)
        end
        fab!(:word3) do
          Fabricate(
            :watched_word,
            action: WatchedWord.actions[:tag],
            replacement: tag3.name,
            case_sensitive: true,
          )
        end

        it "adds watched words as tags" do
          topic =
            TopicCreator.create(
              user,
              Guardian.new(user),
              valid_attrs.merge(
                title: "This is a #{word1.word} title",
                raw: "#{word2.word.upcase} is not the same as #{word3.word.upcase}",
              ),
            )

          expect(topic).to be_valid
          expect(topic.tags).to contain_exactly(tag1, tag2)
        end
      end

      context "with skip_validations option" do
        it "allows the user to add tags even if they're not permitted" do
          SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
          user.update!(trust_level: TrustLevel[1])
          Group.user_trust_level_change!(user.id, user.trust_level)
          topic =
            TopicCreator.create(
              user,
              Guardian.new(user),
              valid_attrs.merge(
                title: "This is a valid title",
                raw: "Somewhat lengthy body for my cool topic",
                tags: [tag1.name, tag2.name, "brandnewtag434"],
                skip_validations: true,
              ),
            )
          expect(topic).to be_persisted
          expect(topic.tags.pluck(:name)).to contain_exactly(tag1.name, tag2.name, "brandnewtag434")
        end
      end

      context "with staff-only tags" do
        before { create_staff_only_tags(["alpha"]) }

        it "regular users can't add staff-only tags" do
          expect do
            TopicCreator.create(user, Guardian.new(user), valid_attrs.merge(tags: ["alpha"]))
          end.to raise_error(ActiveRecord::Rollback)
        end

        it "staff can add staff-only tags" do
          topic =
            TopicCreator.create(admin, Guardian.new(admin), valid_attrs.merge(tags: ["alpha"]))
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(1)
        end
      end

      context "when minimum_required_tags is present" do
        fab!(:category) { Fabricate(:category, name: "beta", minimum_required_tags: 2) }

        it "fails for regular user if minimum_required_tags is not satisfied" do
          expect(
            TopicCreator.new(
              user,
              Guardian.new(user),
              valid_attrs.merge(category: category.id),
            ).valid?,
          ).to be_falsy
        end

        it "lets admin create a topic regardless of minimum_required_tags" do
          topic =
            TopicCreator.create(
              admin,
              Guardian.new(admin),
              valid_attrs.merge(tags: [tag1.name], category: category.id),
            )
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(1)
        end

        it "works for regular user if minimum_required_tags is satisfied" do
          topic =
            TopicCreator.create(
              user,
              Guardian.new(user),
              valid_attrs.merge(tags: [tag1.name, tag2.name], category: category.id),
            )
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(2)
        end

        it "minimum_required_tags is satisfying for new tags if user can create" do
          topic =
            TopicCreator.create(
              user,
              Guardian.new(user),
              valid_attrs.merge(tags: ["new tag", "another tag"], category: category.id),
            )
          expect(topic).to be_valid
          expect(topic.tags.length).to eq(2)
        end

        it "lets new user create a topic if they don't have sufficient trust level to tag topics" do
          SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
          new_user = Fabricate(:newuser, refresh_auto_groups: true)
          topic =
            TopicCreator.create(
              new_user,
              Guardian.new(new_user),
              valid_attrs.merge(category: category.id),
            )
          expect(topic).to be_valid
        end
      end

      context "with required tag group" do
        fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1]) }
        fab!(:category) do
          Fabricate(
            :category,
            name: "beta",
            category_required_tag_groups: [
              CategoryRequiredTagGroup.new(tag_group: tag_group, min_count: 1),
            ],
          )
        end

        it "when no tags are not present" do
          expect(
            TopicCreator.new(
              user,
              Guardian.new(user),
              valid_attrs.merge(category: category.id),
            ).valid?,
          ).to be_falsy
        end

        it "when tags are not part of the tag group" do
          expect(
            TopicCreator.new(
              user,
              Guardian.new(user),
              valid_attrs.merge(category: category.id, tags: ["nope"]),
            ).valid?,
          ).to be_falsy
        end

        it "when requirement is met" do
          expect(
            TopicCreator.new(
              user,
              Guardian.new(user),
              valid_attrs.merge(category: category.id, tags: [tag1.name, tag2.name]),
            ).valid?,
          ).to be_truthy
        end

        it "lets staff ignore the restriction" do
          expect(
            TopicCreator.new(
              user,
              Guardian.new(admin),
              valid_attrs.merge(category: category.id),
            ).valid?,
          ).to be_truthy
        end
      end

      context "when category has restricted tags or tag groups" do
        fab!(:category) { Fabricate(:category, tags: [tag3], tag_groups: [tag_group1]) }

        it "allows topics without any tags" do
          tc =
            TopicCreator.new(
              user,
              Guardian.new(user),
              title: "hello this is a test topic without tags",
              raw: "hello this is a test topic without tags",
              category: category.id,
            )
          expect(tc.valid?).to eq(true)
          expect(tc.errors).to be_empty
          topic = tc.create
          expect(topic.tags).to be_empty
        end

        it "allows topics if they use tags only from the tags set that the category restricts" do
          tc =
            TopicCreator.new(
              user,
              Guardian.new(user),
              title: "hello this is a test topic with tags",
              raw: "hello this is a test topic with tags",
              category: category.id,
              tags: [tag1.name, tag3.name],
            )
          expect(tc.valid?).to eq(true)
          expect(tc.errors).to be_empty
          topic = tc.create
          expect(topic.tags).to contain_exactly(tag1, tag3)
        end

        it "allows topics to use tags that are restricted in multiple categories" do
          category2 = Fabricate(:category, tags: [tag5], tag_groups: [tag_group1])
          tc =
            TopicCreator.new(
              user,
              Guardian.new(user),
              title: "hello this is a test topic with tags",
              raw: "hello this is a test topic with tags",
              category: category2.id,
              tags: [tag1.name, tag5.name],
            )
          expect(tc.valid?).to eq(true)
          expect(tc.errors).to be_empty
          topic = tc.create
          expect(topic.tags).to contain_exactly(tag1, tag5)

          tc =
            TopicCreator.new(
              user,
              Guardian.new(user),
              title: "hello this is a test topic with tags 1",
              raw: "hello this is a test topic with tags",
              category: category.id,
              tags: [tag1.name, tag3.name],
            )
          expect(tc.valid?).to eq(true)
          expect(tc.errors).to be_empty
          topic = tc.create
          expect(topic.tags).to contain_exactly(tag1, tag3)

          tc =
            TopicCreator.new(
              user,
              Guardian.new(user),
              title: "hello this is a test topic with tags 2",
              raw: "hello this is a test topic with tags",
              category: category.id,
              tags: [tag1.name, tag5.name],
            )
          expect(tc.valid?).to eq(false)
          expect(tc.errors.full_messages).to contain_exactly(
            I18n.t(
              "tags.forbidden.restricted_tags_cannot_be_used_in_category",
              count: 1,
              tags: tag5.name,
              category: category.name,
            ),
          )
        end

        it "rejects topics if they use a tag outside the set of tags that the category restricts" do
          tc =
            TopicCreator.new(
              user,
              Guardian.new(user),
              title: "hello this is a test topic with tags",
              raw: "hello this is a test topic with tags",
              category: category.id,
              tags: [tag2.name, tag1.name],
            )
          expect(tc.valid?).to eq(false)
          expect(tc.errors.full_messages).to contain_exactly(
            I18n.t(
              "tags.forbidden.category_does_not_allow_tags",
              count: 1,
              tags: tag2.name,
              category: category.name,
            ),
          )

          tc =
            TopicCreator.new(
              user,
              Guardian.new(user),
              title: "hello this is a test topic with tags",
              raw: "hello this is a test topic with tags",
              category: category.id,
              tags: [tag2.name, tag5.name, tag3.name],
            )
          expect(tc.valid?).to eq(false)
          expect(tc.errors.full_messages).to contain_exactly(
            I18n.t(
              "tags.forbidden.category_does_not_allow_tags",
              count: 2,
              tags: [tag2, tag5].map(&:name).sort.join(", "),
              category: category.name,
            ),
          )
        end

        it "rejects topics in other categories if a restricted tag of a category are used" do
          category2 = Fabricate(:category)
          tc =
            TopicCreator.new(
              user,
              Guardian.new(user),
              title: "hello this is a test topic with tags",
              raw: "hello this is a test topic with tags",
              category: category2.id,
              tags: [tag1.name, tag2.name],
            )
          expect(tc.valid?).to eq(false)
          expect(tc.errors.full_messages).to contain_exactly(
            I18n.t(
              "tags.forbidden.restricted_tags_cannot_be_used_in_category",
              count: 1,
              tags: tag1.name,
              category: category2.name,
            ),
          )
        end

        context "when allowing other tags" do
          before { category.update!(allow_global_tags: true) }

          it "allows topics to use tags that aren't restricted by any category" do
            tc =
              TopicCreator.new(
                user,
                Guardian.new(user),
                title: "hello this is a test topic with tags",
                raw: "hello this is a test topic with tags",
                category: category.id,
                tags: [tag1.name, tag2.name, tag3.name, tag5.name],
              )
            expect(tc.valid?).to eq(true)
            expect(tc.errors).to be_empty
            topic = tc.create
            expect(topic.tags).to contain_exactly(tag1, tag2, tag3, tag5)
          end

          it "rejects topics if they use restricted tags of another category" do
            Fabricate(:category, tags: [tag5], tag_groups: [tag_group2])
            tc =
              TopicCreator.new(
                user,
                Guardian.new(user),
                title: "hello this is a test topic with tags",
                raw: "hello this is a test topic with tags",
                category: category.id,
                tags: [tag1.name, tag5.name],
              )
            expect(tc.valid?).to eq(false)
            expect(tc.errors.full_messages).to contain_exactly(
              I18n.t(
                "tags.forbidden.restricted_tags_cannot_be_used_in_category",
                count: 1,
                tags: tag5.name,
                category: category.name,
              ),
            )

            tc =
              TopicCreator.new(
                user,
                Guardian.new(user),
                title: "hello this is a test topic with tags",
                raw: "hello this is a test topic with tags",
                category: category.id,
                tags: [tag1.name, tag2.name, tag5.name],
              )
            expect(tc.valid?).to eq(false)
            expect(tc.errors.full_messages).to contain_exactly(
              I18n.t(
                "tags.forbidden.restricted_tags_cannot_be_used_in_category",
                count: 2,
                tags: [tag2, tag5].map(&:name).sort.join(", "),
                category: category.name,
              ),
            )
          end
        end
      end
    end

    context "with personal message" do
      context "with success cases" do
        before do
          TopicCreator.any_instance.expects(:save_topic).returns(true)
          TopicCreator.any_instance.expects(:watch_topic).returns(true)
          SiteSetting.allow_duplicate_topic_titles = true
          SiteSetting.enable_staged_users = true
        end

        it "should be possible for a regular user to send private message" do
          expect(TopicCreator.create(user, Guardian.new(user), pm_valid_attrs)).to be_valid
        end

        it "create_topic_allowed_groups setting should not be checked when sending private message" do
          SiteSetting.create_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
          expect(TopicCreator.create(user, Guardian.new(user), pm_valid_attrs)).to be_valid
        end

        it "personal_message_enabled_groups setting should not be checked when sending private messages to staff via flag" do
          SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff]
          expect(
            TopicCreator.create(
              user,
              Guardian.new(user),
              pm_valid_attrs.merge(subtype: TopicSubtype.notify_moderators),
            ),
          ).to be_valid
        end
      end

      context "with failure cases" do
        it "should be rollback the changes when email is invalid" do
          SiteSetting.manual_polling_enabled = true
          SiteSetting.reply_by_email_address = "sam+%{reply_key}@sam.com"
          SiteSetting.reply_by_email_enabled = true
          SiteSetting.send_email_messages_allowed_groups =
            "1|3|#{Group::AUTO_GROUPS[:trust_level_1]}"
          attrs = pm_to_email_valid_attrs.dup
          attrs[:target_emails] = "t" * 256

          expect do TopicCreator.create(user, Guardian.new(user), attrs) end.to raise_error(
            ActiveRecord::Rollback,
          )
        end

        it "personal_message_enabled_groups setting should be checked when sending private message" do
          SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4]

          expect do
            TopicCreator.create(user, Guardian.new(user), pm_valid_attrs)
          end.to raise_error(ActiveRecord::Rollback)
        end
      end

      context "with too many users in a group" do
        fab!(:group) { Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]) }

        before do
          SiteSetting.group_pm_user_limit = 1
          Fabricate.times(2, :user).each { |user| group.add(user) }
          pm_valid_attrs[:target_group_names] = group.name
        end

        it "fails with an error" do
          expect do
            TopicCreator.create(user, Guardian.new(admin), pm_valid_attrs)
          end.to raise_error(
            ActiveRecord::Rollback,
            I18n.t(
              "activerecord.errors.models.topic.attributes.base.too_large_group",
              limit: SiteSetting.group_pm_user_limit,
              group_name: group.name,
            ),
          )
        end
      end

      context "with to emails" do
        it "works for staff" do
          SiteSetting.send_email_messages_allowed_groups = "1|3"
          expect(
            TopicCreator.create(admin, Guardian.new(admin), pm_to_email_valid_attrs),
          ).to be_valid
        end

        it "work for trusted users" do
          SiteSetting.send_email_messages_allowed_groups =
            "1|3|#{Group::AUTO_GROUPS[:trust_level_3]}"
          user.change_trust_level!(TrustLevel[3])
          expect(TopicCreator.create(user, Guardian.new(user), pm_to_email_valid_attrs)).to be_valid
        end

        it "does not work for non-staff" do
          SiteSetting.send_email_messages_allowed_groups = "1|3"
          expect {
            TopicCreator.create(user, Guardian.new(user), pm_to_email_valid_attrs)
          }.to raise_error(ActiveRecord::Rollback)
        end

        it "does not work for untrusted users" do
          SiteSetting.send_email_messages_allowed_groups =
            "1|3|#{Group::AUTO_GROUPS[:trust_level_3]}"
          user.change_trust_level!(TrustLevel[2])
          expect {
            TopicCreator.create(user, Guardian.new(user), pm_to_email_valid_attrs)
          }.to raise_error(ActiveRecord::Rollback)
        end
      end
    end

    context "when setting timestamps" do
      it "supports Time instances" do
        freeze_time

        topic =
          TopicCreator.create(
            user,
            Guardian.new(user),
            valid_attrs.merge(created_at: 1.week.ago, pinned_at: 3.days.ago),
          )

        expect(topic.created_at).to eq_time(1.week.ago)
        expect(topic.pinned_at).to eq_time(3.days.ago)
      end

      it "supports strings" do
        freeze_time

        time1 = Time.zone.parse("2019-09-02")
        time2 = Time.zone.parse("2020-03-10 15:17")

        topic =
          TopicCreator.create(
            user,
            Guardian.new(user),
            valid_attrs.merge(created_at: "2019-09-02", pinned_at: "2020-03-10 15:17"),
          )

        expect(topic.created_at).to eq_time(time1)
        expect(topic.pinned_at).to eq_time(time2)
      end
    end

    context "with external_id" do
      it "adds external_id" do
        topic =
          TopicCreator.create(
            user,
            Guardian.new(user),
            valid_attrs.merge(external_id: "external_id"),
          )

        expect(topic.external_id).to eq("external_id")
      end
    end

    context "when invisible/unlisted" do
      let(:unlisted_attrs) { valid_attrs.merge(visible: false) }

      it "throws an exception for a non-staff user" do
        expect do TopicCreator.create(user, Guardian.new(user), unlisted_attrs) end.to raise_error(
          ActiveRecord::Rollback,
        )
      end

      it "is invalid for a non-staff user" do
        expect(TopicCreator.new(user, Guardian.new(user), unlisted_attrs).valid?).to eq(false)
      end

      it "creates unlisted topic for an admin" do
        expect(TopicCreator.create(admin, Guardian.new(admin), unlisted_attrs)).to be_valid
      end

      it "is valid for an admin" do
        expect(TopicCreator.new(admin, Guardian.new(admin), unlisted_attrs).valid?).to eq(true)
      end

      context "when embedded" do
        let(:embedded_unlisted_attrs) do
          unlisted_attrs.merge(embed_url: "http://eviltrout.com/stupid-url")
        end

        it "is valid for a non-staff user" do
          expect(TopicCreator.new(user, Guardian.new(user), embedded_unlisted_attrs).valid?).to eq(
            true,
          )
        end
      end
    end
  end
end
