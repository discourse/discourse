# frozen_string_literal: true

RSpec.describe TopicsFilter do
  fab!(:user) { Fabricate(:user, username: "username") }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:group) { Fabricate(:group) }

  describe "#filter_from_query_string" do
    describe "when filtering with multiple filters" do
      fab!(:tag) { Fabricate(:tag, name: "tag1") }
      fab!(:tag2) { Fabricate(:tag, name: "tag2") }
      fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
      fab!(:closed_topic_with_tag) { Fabricate(:topic, tags: [tag], closed: true) }
      fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }
      fab!(:closed_topic_with_tag2) { Fabricate(:topic, tags: [tag2], closed: true) }

      it "should return the right topics when query string is `status:closed tags:tag1,tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:closed tags:tag1,tag2")
            .pluck(:id),
        ).to contain_exactly(closed_topic_with_tag.id, closed_topic_with_tag2.id)
      end
    end

    describe "when filtering with the `in` filter" do
      fab!(:topic) { Fabricate(:topic) }

      fab!(:pinned_topic) do
        Fabricate(:topic, pinned_at: Time.zone.now, pinned_until: 1.hour.from_now)
      end

      fab!(:expired_pinned_topic) do
        Fabricate(:topic, pinned_at: 2.hour.ago, pinned_until: 1.hour.ago)
      end

      describe "when query string is `in:pinned`" do
        it "should return topics that are pinned" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("in:pinned")
              .pluck(:id),
          ).to contain_exactly(pinned_topic.id)
        end

        it "should not return pinned topics that have expired" do
          freeze_time(2.hours.from_now) do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("in:pinned")
                .pluck(:id),
            ).to eq([])
          end
        end
      end

      describe "when query string is `in:bookmarked`" do
        fab!(:bookmark) do
          BookmarkManager.new(user).create_for(
            bookmarkable_id: topic.id,
            bookmarkable_type: "Topic",
          )
        end

        fab!(:bookmark2) do
          BookmarkManager.new(admin).create_for(
            bookmarkable_id: topic.id,
            bookmarkable_type: "Topic",
          )
        end

        it "should not return any topics when user is anonymous" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("in:bookmarked")
              .pluck(:id),
          ).to eq([])
        end

        it "should return topics that are bookmarked" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("in:bookmarked")
              .pluck(:id),
          ).to contain_exactly(topic.id)
        end
      end

      describe "when query string is `in:bookmarked in:pinnned`" do
        it "should return topics that are bookmarked and pinned" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("in:bookmarked in:pinned")
              .pluck(:id),
          ).to eq([])

          BookmarkManager.new(user).create_for(
            bookmarkable_id: pinned_topic.id,
            bookmarkable_type: "Topic",
          )

          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("in:bookmarked in:pinned")
              .pluck(:id),
          ).to contain_exactly(pinned_topic.id)
        end
      end

      TopicUser.notification_levels.keys.each do |notification_level|
        describe "when query string is `in:#{notification_level}`" do
          fab!("user_#{notification_level}_topic".to_sym) do
            Fabricate(:topic).tap do |topic|
              TopicUser.change(
                user.id,
                topic.id,
                notification_level: TopicUser.notification_levels[notification_level],
              )
            end
          end

          it "should not return any topics if the user is anonymous" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("in:#{notification_level}")
                .pluck(:id),
            ).to eq([])
          end

          it "should return topics that the user has notification level set to #{notification_level}" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("in:#{notification_level}")
                .pluck(:id),
            ).to contain_exactly(self.public_send("user_#{notification_level}_topic").id)
          end
        end
      end

      describe "when filtering by multiple topic notification levels" do
        fab!(:user_muted_topic) do
          Fabricate(:topic).tap do |topic|
            TopicUser.change(
              user.id,
              topic.id,
              notification_level: TopicUser.notification_levels[:muted],
            )
          end
        end

        fab!(:user_watching_topic) do
          Fabricate(:topic).tap do |topic|
            TopicUser.change(
              user.id,
              topic.id,
              notification_level: TopicUser.notification_levels[:watching],
            )
          end
        end

        fab!(:user_tracking_topic) do
          Fabricate(:topic).tap do |topic|
            TopicUser.change(
              user.id,
              topic.id,
              notification_level: TopicUser.notification_levels[:tracking],
            )
          end
        end

        describe "when query string is `in:muted,invalid`" do
          it "should ignore the invalid notification level" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("in:muted,invalid")
                .pluck(:id),
            ).to contain_exactly(user_muted_topic.id)
          end
        end

        describe "when query string is `in:muted in:tracking`" do
          it "should return topics that the user is tracking or has muted" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("in:muted in:tracking")
                .pluck(:id),
            ).to contain_exactly(user_muted_topic.id, user_tracking_topic.id)
          end
        end

        describe "when query string is `in:muted,tracking" do
          it "should return topics that the user is tracking or has muted" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new(user))
                .filter_from_query_string("in:muted,tracking")
                .pluck(:id),
            ).to contain_exactly(user_muted_topic.id, user_tracking_topic.id)
          end
        end
      end
    end

    describe "when filtering by categories" do
      fab!(:category) { Fabricate(:category, name: "category") }

      fab!(:category_subcategory) do
        Fabricate(:category, parent_category: category, name: "category subcategory")
      end

      fab!(:category2) { Fabricate(:category, name: "category2") }

      fab!(:category2_subcategory) do
        Fabricate(:category, parent_category: category2, name: "category2 subcategory")
      end

      fab!(:private_category) do
        Fabricate(:private_category, group: group, slug: "private-category")
      end

      fab!(:topic_in_category) { Fabricate(:topic, category: category) }
      fab!(:topic_in_category_subcategory) { Fabricate(:topic, category: category_subcategory) }
      fab!(:topic_in_category2) { Fabricate(:topic, category: category2) }
      fab!(:topic_in_category2_subcategory) { Fabricate(:topic, category: category2_subcategory) }
      fab!(:topic_in_private_category) { Fabricate(:topic, category: private_category) }

      describe "when query string is `-category:category`" do
        it "ignores the filter because the prefix is invalid" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("-category:category")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
            topic_in_category2.id,
            topic_in_category2_subcategory.id,
            topic_in_private_category.id,
          )
        end
      end

      describe "when query string is `category:private-category`" do
        it "should not return any topics when user does not have access to specified category" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:private-category")
              .pluck(:id),
          ).to eq([])
        end

        it "should return topics from specified category when user has access to specified category" do
          group.add(user)

          expect(
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("category:private-category")
              .pluck(:id),
          ).to contain_exactly(topic_in_private_category.id)
        end
      end

      describe "when query string is `category:category`" do
        it "should return topics from specified category and its subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category")
              .pluck(:id),
          ).to contain_exactly(topic_in_category.id, topic_in_category_subcategory.id)
        end

        it "should return topics from specified category, its subcategories and sub-subcategories" do
          SiteSetting.max_category_nesting = 3

          category_subcategory_subcategory =
            Fabricate(
              :category,
              parent_category: category_subcategory,
              name: "category subcategory subcategory",
            )

          topic_in_category_subcategory_subcategory =
            Fabricate(:topic, category: category_subcategory_subcategory)

          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
            topic_in_category_subcategory_subcategory.id,
          )
        end
      end

      describe "when query string is `category:category,category2`" do
        it "should return topics from any of the specified categories and its subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category,category2")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
            topic_in_category2.id,
            topic_in_category2_subcategory.id,
          )
        end
      end

      describe "when query string is `category:category category:category2`" do
        it "should return topics from any of the specified categories and its subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category category:category2")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
            topic_in_category2.id,
            topic_in_category2_subcategory.id,
          )
        end
      end

      describe "when query string is `category:category =category:category2`" do
        it "should return topics and subcategory topics from category but only topics from category2" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("category:category =category:category2")
              .pluck(:id),
          ).to contain_exactly(
            topic_in_category.id,
            topic_in_category_subcategory.id,
            topic_in_category2.id,
          )
        end
      end

      describe "when query string is `=category:category`" do
        it "should not return topics from subcategories`" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("=category:category")
              .pluck(:id),
          ).to contain_exactly(topic_in_category.id)
        end
      end

      describe "when query string is `=category:category,category2`" do
        it "should not return topics from subcategories" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("=category:category,category2")
              .pluck(:id),
          ).to contain_exactly(topic_in_category.id, topic_in_category2.id)
        end
      end

      describe "when multiple categories have subcategories with the same name" do
        fab!(:category_subcategory) do
          Fabricate(:category, parent_category: category, name: "subcategory")
        end

        fab!(:category2_subcategory) do
          Fabricate(:category, parent_category: category2, name: "subcategory")
        end

        fab!(:topic_in_category_subcategory) { Fabricate(:topic, category: category_subcategory) }
        fab!(:topic_in_category2_subcategory) { Fabricate(:topic, category: category2_subcategory) }

        describe "when query string is `category:subcategory`" do
          it "should return topics from subcategories of both categories" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:subcategory")
                .pluck(:id),
            ).to contain_exactly(
              topic_in_category_subcategory.id,
              topic_in_category2_subcategory.id,
            )
          end
        end

        describe "when query string is `category:category:subcategory`" do
          it "should return topics from subcategories of the specified category" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:category:subcategory")
                .pluck(:id),
            ).to contain_exactly(topic_in_category_subcategory.id)
          end
        end

        describe "when query string is `category:category2:subcategory`" do
          it "should return topics from subcategories of the specified category" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:category2:subcategory")
                .pluck(:id),
            ).to contain_exactly(topic_in_category2_subcategory.id)
          end
        end

        describe "when query string is `category:category:subcategory,category2:subcategory`" do
          it "should return topics from either subcategory" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("category:category:subcategory,category2:subcategory")
                .pluck(:id),
            ).to contain_exactly(
              topic_in_category_subcategory.id,
              topic_in_category2_subcategory.id,
            )
          end
        end

        describe "when max category nesting is 3" do
          fab!(:category_subcategory_subcategory) do
            SiteSetting.max_category_nesting = 3
            Fabricate(:category, parent_category: category_subcategory, name: "sub-subcategory")
          end

          fab!(:category2_subcategory_subcategory) do
            SiteSetting.max_category_nesting = 3
            Fabricate(:category, parent_category: category2_subcategory, name: "sub-subcategory")
          end

          fab!(:topic_in_category_subcategory_subcategory) do
            Fabricate(:topic, category: category_subcategory_subcategory)
          end

          fab!(:topic_in_category2_subcategory_subcategory) do
            Fabricate(:topic, category: category2_subcategory_subcategory)
          end

          before { SiteSetting.max_category_nesting = 3 }

          describe "when query string is `category:category:subcategory:sub-subcategory`" do
            it "return topics from category with slug 'sub-subcategory' with the category ancestor chain of 'subcategory' and 'category'" do
              expect(
                TopicsFilter
                  .new(guardian: Guardian.new)
                  .filter_from_query_string("category:category:subcategory:sub-subcategory")
                  .pluck(:id),
              ).to contain_exactly(topic_in_category_subcategory_subcategory.id)
            end
          end

          describe "when query string is `=category:category2:subcategory`" do
            it "return topics from category with slug 'subcategory' with the category ancestor chain of 'category2'" do
              expect(
                TopicsFilter
                  .new(guardian: Guardian.new)
                  .filter_from_query_string("=category:category2:subcategory")
                  .pluck(:id),
              ).to contain_exactly(topic_in_category2_subcategory.id)
            end
          end

          describe "when query string is `category:category2:subcategory`" do
            it "return topics and subcategories topics from category with slug 'subcategory' with the category ancestor chain of 'category2'" do
              category2_subcategory_subcategory2 =
                Fabricate(
                  :category,
                  parent_category: category2_subcategory,
                  name: "sub-subcategory2",
                )

              topic_in_category2_subcategory_subcategory2 =
                Fabricate(:topic, category: category2_subcategory_subcategory2)

              expect(
                TopicsFilter
                  .new(guardian: Guardian.new)
                  .filter_from_query_string("category:category2:subcategory")
                  .pluck(:id),
              ).to contain_exactly(
                topic_in_category2_subcategory.id,
                topic_in_category2_subcategory_subcategory.id,
                topic_in_category2_subcategory_subcategory2.id,
              )
            end
          end

          describe "when query string is `category:sub-subcategory`" do
            it "return topics from either category with slug 'sub-subcategory'" do
              expect(
                TopicsFilter
                  .new(guardian: Guardian.new)
                  .filter_from_query_string("category:sub-subcategory")
                  .pluck(:id),
              ).to contain_exactly(
                topic_in_category_subcategory_subcategory.id,
                topic_in_category2_subcategory_subcategory.id,
              )
            end
          end
        end
      end
    end

    describe "when filtering by status" do
      fab!(:topic) { Fabricate(:topic) }
      fab!(:closed_topic) { Fabricate(:topic, closed: true) }
      fab!(:archived_topic) { Fabricate(:topic, archived: true) }
      fab!(:deleted_topic_id) { Fabricate(:topic, deleted_at: Time.zone.now).id }

      it "should only return topics that have not been closed or archived when query string is `status:open`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:open")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that have been deleted when query string is `status:deleted` and user can see deleted topics" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new(admin))
            .filter_from_query_string("status:deleted")
            .pluck(:id),
        ).to contain_exactly(deleted_topic_id)
      end

      it "should ignore status filter when query string is `status:deleted` and user cannot see deleted topics" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:deleted")
            .pluck(:id),
        ).to contain_exactly(topic.id, closed_topic.id, archived_topic.id)
      end

      it "should only return topics that have been archived when query string is `status:archived`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:archived")
            .pluck(:id),
        ).to contain_exactly(archived_topic.id)
      end

      it "should only return topics that are visible when query string is `status:listed`" do
        Topic.update_all(visible: false)
        topic.update!(visible: true)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:listed")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that are not visible when query string is `status:unlisted`" do
        Topic.update_all(visible: true)
        topic.update!(visible: false)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:unlisted")
            .pluck(:id),
        ).to contain_exactly(topic.id)
      end

      it "should only return topics that are not in any read-restricted category when query string is `status:public`" do
        private_category = Fabricate(:private_category, group: group)
        topic_in_private_category = Fabricate(:topic, category: private_category)

        expect(
          TopicsFilter.new(guardian: Guardian.new).filter_from_query_string("").pluck(:id),
        ).to include(topic_in_private_category.id)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("status:public")
            .pluck(:id),
        ).not_to include(topic_in_private_category.id)
      end

      describe "when query string is `status:closed status:unlisted`" do
        fab!(:closed_and_unlisted_topic) { Fabricate(:topic, closed: true, visible: false) }

        it "should only return topics that have been closed and are not visible" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("status:closed status:unlisted")
              .pluck(:id),
          ).to contain_exactly(closed_and_unlisted_topic.id)
        end
      end
    end

    describe "when filtering by tags" do
      fab!(:tag) { Fabricate(:tag, name: "tag1") }
      fab!(:tag2) { Fabricate(:tag, name: "tag2") }
      fab!(:tag3) { Fabricate(:tag, name: "tag3") }

      fab!(:group_only_tag) { Fabricate(:tag, name: "group-only-tag") }
      fab!(:group) { Fabricate(:group) }

      let!(:staff_tag_group) do
        Fabricate(
          :tag_group,
          permissions: {
            group.name => TagGroupPermission.permission_types[:full],
          },
          tag_names: [group_only_tag.name],
        )
      end

      fab!(:topic_without_tag) { Fabricate(:topic) }
      fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
      fab!(:topic_with_tag_and_tag2) { Fabricate(:topic, tags: [tag, tag2]) }
      fab!(:topic_with_tag2) { Fabricate(:topic, tags: [tag2]) }
      fab!(:topic_with_group_only_tag) { Fabricate(:topic, tags: [group_only_tag]) }

      it "should not filter any topics by tags when tagging is disabled" do
        SiteSetting.tagging_enabled = false

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name}+#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(
          topic_without_tag.id,
          topic_with_tag.id,
          topic_with_tag_and_tag2.id,
          topic_with_tag2.id,
          topic_with_group_only_tag.id,
        )
      end

      it "should only return topics that are tagged with all of the specified tags when query string is `tags:tag1+tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name}+#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id)
      end

      it "should only return topics that are tagged with tag1 and tag2 when query string is `tags:tag1 tags:tag2`" do
        topic_with_tag_and_tag2_and_tag3 = Fabricate(:topic, tags: [tag, tag2, tag3])

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name} tags:#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id, topic_with_tag_and_tag2_and_tag3.id)
      end

      it "should only return topics that are tagged with tag1 and tag2 but not tag3 when query string is `tags:tag1 tags:tag2 -tags:tag3`" do
        topic_with_tag_and_tag2_and_tag3 = Fabricate(:topic, tags: [tag, tag2, tag3])

        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name} tags:#{tag2.name} -tags:tag3")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id)
      end

      it "should only return topics that are tagged with any of the specified tags when query string is `tags:tag1,tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:#{tag.name},#{tag2.name}")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag.id, topic_with_tag_and_tag2.id, topic_with_tag2.id)
      end

      it "should not return any topics when query string is `tags:tag1+tag2+invalid`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:tag1+tag2+invalid")
            .pluck(:id),
        ).to eq([])
      end

      it "should still filter topics by specificed tags when query string is `tags:tag1,tag2,invalid`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:tag1,tag2,invalid")
            .pluck(:id),
        ).to contain_exactly(topic_with_tag_and_tag2.id, topic_with_tag.id, topic_with_tag2.id)
      end

      it "should not return any topics when query string is `tags:group-only-tag` because specified tag is hidden to user" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("tags:group-only-tag")
            .pluck(:id),
        ).to eq([])
      end

      it "should return the right topics when query string is `tags:group-only-tag` and user has access to specified tag" do
        group.add(admin)

        expect(
          TopicsFilter
            .new(guardian: Guardian.new(admin))
            .filter_from_query_string("tags:group-only-tag")
            .pluck(:id),
        ).to contain_exactly(topic_with_group_only_tag.id)
      end

      it "should only return topics that are not tagged with specified tag when query string is `-tags:tag1`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tags:tag1")
            .pluck(:id),
        ).to contain_exactly(topic_without_tag.id, topic_with_tag2.id, topic_with_group_only_tag.id)
      end

      it "should only return topics that are not tagged with all of the specified tags when query string is `-tags:tag1+tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tags:tag1+tag2")
            .pluck(:id),
        ).to contain_exactly(
          topic_without_tag.id,
          topic_with_tag.id,
          topic_with_tag2.id,
          topic_with_group_only_tag.id,
        )
      end

      it "should only return topics that are not tagged with any of the specified tags when query string is `-tags:tag1,tag2`" do
        expect(
          TopicsFilter
            .new(guardian: Guardian.new)
            .filter_from_query_string("-tags:tag1,tag2")
            .pluck(:id),
        ).to contain_exactly(topic_without_tag.id, topic_with_group_only_tag.id)
      end
    end

    describe "when filtering by topic author" do
      fab!(:user2) { Fabricate(:user, username: "username2") }
      fab!(:topic_by_user) { Fabricate(:topic, user: user) }
      fab!(:topic2_by_user) { Fabricate(:topic, user: user) }
      fab!(:topic_by_user2) { Fabricate(:topic, user: user2) }

      describe "when query string is `created-by:username`" do
        it "should return the topics created by the specified user" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:#{user.username}")
              .pluck(:id),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id)
        end
      end

      describe "when query string is `created-by:username2`" do
        it "should return the topics created by the specified user" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:#{user2.username}")
              .pluck(:id),
          ).to contain_exactly(topic_by_user2.id)
        end
      end

      describe "when query string is `created-by:username created-by:username2`" do
        it "should return the topics created by either of the specified users" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:#{user.username} created-by:#{user2.username}")
              .pluck(:id),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id, topic_by_user2.id)
        end
      end

      describe "when query string is `created-by:username,invalid`" do
        it "should only return the topics created by the user with the valid username" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:#{user.username},invalid")
              .pluck(:id),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id)
        end
      end

      describe "when query string is `created-by:username,username2`" do
        it "should return the topics created by either of the specified users" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:#{user.username},#{user2.username}")
              .pluck(:id),
          ).to contain_exactly(topic_by_user.id, topic2_by_user.id, topic_by_user2.id)
        end
      end

      describe "when query string is `created-by:invalid`" do
        it "should not return any topics" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("created-by:invalid")
              .pluck(:id),
          ).to eq([])
        end
      end
    end

    shared_examples "filtering for topics by counts" do |filter|
      describe "when query string is `#{filter}-min:1`" do
        it "should only return topics with at least 1 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-min:1")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id, topic_with_2_count.id, topic_with_3_count.id)
        end
      end

      describe "when query string is `#{filter}-min:3`" do
        it "should only return topics with at least 3 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-min:3")
              .pluck(:id),
          ).to contain_exactly(topic_with_3_count.id)
        end
      end

      describe "when query string is `#{filter}-max:1`" do
        it "should only return topics with at most 1 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-max:1")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id)
        end
      end

      describe "when query string is `#{filter}-max:3`" do
        it "should only return topics with at most 3 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-max:3")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id, topic_with_2_count.id, topic_with_3_count.id)
        end
      end

      describe "when query string is `#{filter}-min:1 #{filter}-max:2`" do
        it "should only return topics with at least 1 like and at most 2 #{filter}" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-min:1 #{filter}-max:2")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id, topic_with_2_count.id)
        end
      end

      describe "when query string is `#{filter}-min:3 #{filter}-min:2 #{filter}-max:1 #{filter}-max:3`" do
        it "should only return topics with at least 2 #{filter} and at most 3 #{filter} as it ignores earlier filters which are duplicated" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string(
                "#{filter}-min:3 #{filter}-min:2 #{filter}-max:1 #{filter}-max:3",
              )
              .pluck(:id),
          ).to contain_exactly(topic_with_2_count.id, topic_with_3_count.id)
        end
      end

      describe "when query string is `#{filter}-min:invalid #{filter}-max:invalid`" do
        it "should ignore the filters with invalid values" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-min:invalid #{filter}-max:invalid")
              .pluck(:id),
          ).to contain_exactly(topic_with_1_count.id, topic_with_2_count.id, topic_with_3_count.id)
        end
      end
    end

    describe "when filtering by number of likes in a topic" do
      fab!(:topic_with_1_count) { Fabricate(:topic, like_count: 1) }
      fab!(:topic_with_2_count) { Fabricate(:topic, like_count: 2) }
      fab!(:topic_with_3_count) { Fabricate(:topic, like_count: 3) }

      include_examples("filtering for topics by counts", "likes")
    end

    describe "when filtering by number of posters in a topic" do
      fab!(:topic_with_1_count) { Fabricate(:topic, participant_count: 1) }
      fab!(:topic_with_2_count) { Fabricate(:topic, participant_count: 2) }
      fab!(:topic_with_3_count) { Fabricate(:topic, participant_count: 3) }

      include_examples("filtering for topics by counts", "posters")
    end

    describe "when filtering by number of posts in a topic" do
      fab!(:topic_with_1_count) { Fabricate(:topic, posts_count: 1) }
      fab!(:topic_with_2_count) { Fabricate(:topic, posts_count: 2) }
      fab!(:topic_with_3_count) { Fabricate(:topic, posts_count: 3) }

      include_examples("filtering for topics by counts", "posts")
    end

    describe "when filtering by number of views in a topic" do
      fab!(:topic_with_1_count) { Fabricate(:topic, views: 1) }
      fab!(:topic_with_2_count) { Fabricate(:topic, views: 2) }
      fab!(:topic_with_3_count) { Fabricate(:topic, views: 3) }

      include_examples("filtering for topics by counts", "views")
    end

    describe "when filtering by number of likes in the first post of a topic" do
      fab!(:topic_with_1_count) do
        post = Fabricate(:post, like_count: 1)
        post.topic
      end

      fab!(:topic_with_2_count) do
        post = Fabricate(:post, like_count: 2)
        post.topic
      end

      fab!(:topic_with_3_count) do
        post = Fabricate(:post, like_count: 3)
        post.topic
      end

      include_examples("filtering for topics by counts", "likes-op")
    end

    shared_examples "filtering for topics by date column" do |filter, column, description|
      fab!(:topic) { Fabricate(:topic, column => Time.zone.local(2022, 1, 1)) }
      fab!(:topic2) { Fabricate(:topic, column => Time.zone.local(2023, 5, 12)) }

      describe "when query string is `#{filter}-after:invalid-date-test`" do
        it "should ignore the filter" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-after:invalid-date-test")
              .pluck(:id),
          ).to contain_exactly(topic.id, topic2.id)
        end
      end

      describe "when query string is `#{filter}-after:2022-01-01`" do
        it "should only return topics with #{description} after 2022-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-after:2022-01-01")
              .pluck(:id),
          ).to contain_exactly(topic.id, topic2.id)
        end
      end

      describe "when query string is `#{filter}-after:2023-01-1`" do
        it "should only return topics with #{description} after 2023-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-after:2023-01-1")
              .pluck(:id),
          ).to contain_exactly(topic2.id)
        end
      end

      describe "when query string is `#{filter}-after:2023-6-01`" do
        it "should only return topics with #{description} after 2023-06-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-after:2023-6-01")
              .pluck(:id),
          ).to eq([])
        end
      end

      describe "when query string is `#{filter}-before:2023-01-01`" do
        it "should only return topics with #{description} before 2023-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-before:2023-01-01")
              .pluck(:id),
          ).to contain_exactly(topic.id)
        end
      end

      describe "when query string is `#{filter}-before:2023-1-1`" do
        it "should only return topics with #{description} before 2023-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-before:2023-1-1")
              .pluck(:id),
          ).to contain_exactly(topic.id)
        end
      end

      describe "when query string is `#{filter}-before:2000-01-01`" do
        it "should only return topics with #{description} before 2000-01-01" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("#{filter}-before:2000-01-01")
              .pluck(:id),
          ).to eq([])
        end
      end
    end

    describe "when filtering by activity of topics" do
      include_examples "filtering for topics by date column", "activity", :bumped_at, "bumped date"
    end

    describe "when filtering by creation date of topics" do
      include_examples "filtering for topics by date column", "created", :created_at, "created date"
    end

    describe "when filtering by last post date of topics" do
      include_examples "filtering for topics by date column",
                       "latest-post",
                       :last_posted_at,
                       "last posted date"
    end

    describe "ordering topics filter" do
      # Requires the fabrication of `topic`, `topic2` and `topic3` such that the order of the topics is `topic2`, `topic1`, `topic3`
      # when ordered by the given filter in descending order.
      shared_examples "ordering topics filters" do |order, order_description|
        describe "when query string is `order:#{order}`" do
          it "should return topics ordered by #{order_description} in descending order" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:#{order}")
                .pluck(:id),
            ).to eq([topic2.id, topic.id, topic3.id])
          end
        end

        describe "when query string is `order:#{order}-asc`" do
          it "should return topics ordered by #{order_description} in ascending order" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:#{order}-asc")
                .pluck(:id),
            ).to eq([topic3.id, topic.id, topic2.id])
          end
        end

        describe "when query string is `order:#{order}-invalid`" do
          it "should return topics ordered by the default order" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:#{order}-invalid")
                .pluck(:id),
            ).to eq(Topic.all.order(:id).pluck(:id))
          end
        end
      end

      describe "when ordering topics by creation date" do
        fab!(:topic) { Fabricate(:topic, created_at: Time.zone.local(2023, 1, 1)) }
        fab!(:topic2) { Fabricate(:topic, created_at: Time.zone.local(2024, 1, 1)) }
        fab!(:topic3) { Fabricate(:topic, created_at: Time.zone.local(2022, 1, 1)) }

        include_examples "ordering topics filters", "created", "creation date"
      end

      describe "when ordering topics by last activity date" do
        fab!(:topic) { Fabricate(:topic, bumped_at: Time.zone.local(2023, 1, 1)) }
        fab!(:topic2) { Fabricate(:topic, bumped_at: Time.zone.local(2024, 1, 1)) }
        fab!(:topic3) { Fabricate(:topic, bumped_at: Time.zone.local(2022, 1, 1)) }

        include_examples "ordering topics filters", "activity", "bumped date"
      end

      describe "when ordering topics by number of likes in the topic" do
        fab!(:topic) { Fabricate(:topic, like_count: 2) }
        fab!(:topic2) { Fabricate(:topic, like_count: 3) }
        fab!(:topic3) { Fabricate(:topic, like_count: 1) }

        include_examples "ordering topics filters", "likes", "number of likes in the topic"
      end

      describe "when ordering topics by number of participants in the topic" do
        fab!(:topic) { Fabricate(:topic, participant_count: 2) }
        fab!(:topic2) { Fabricate(:topic, participant_count: 3) }
        fab!(:topic3) { Fabricate(:topic, participant_count: 1) }

        include_examples "ordering topics filters", "posters", "number of participants in the topic"
      end

      describe "when ordering topics by number of topics views" do
        fab!(:topic) { Fabricate(:topic, views: 2) }
        fab!(:topic2) { Fabricate(:topic, views: 3) }
        fab!(:topic3) { Fabricate(:topic, views: 1) }

        include_examples "ordering topics filters", "views", "number of views"
      end

      describe "when ordering topics by latest post creation date" do
        fab!(:topic) { Fabricate(:topic, last_posted_at: Time.zone.local(2023, 1, 1)) }
        fab!(:topic2) { Fabricate(:topic, last_posted_at: Time.zone.local(2024, 1, 1)) }
        fab!(:topic3) { Fabricate(:topic, last_posted_at: Time.zone.local(2022, 1, 1)) }

        include_examples "ordering topics filters", "latest-post", "latest post creation date"
      end

      describe "when ordering topics by number of likes in the first post" do
        fab!(:topic) do
          post = Fabricate(:post, like_count: 2)
          post.topic
        end

        fab!(:topic2) do
          post = Fabricate(:post, like_count: 3)
          post.topic
        end

        fab!(:topic3) do
          post = Fabricate(:post, like_count: 1)
          post.topic
        end

        include_examples "ordering topics filters", "likes-op", "number of likes in the first post"
      end

      describe "when ordering by topics's category name" do
        fab!(:category) { Fabricate(:category, name: "Category 1") }
        fab!(:category2) { Fabricate(:category, name: "Category 2") }
        fab!(:category3) { Fabricate(:category, name: "Category 3") }

        fab!(:topic) { Fabricate(:topic, category: category2) }
        fab!(:topic2) { Fabricate(:topic, category: category3) }
        fab!(:topic3) { Fabricate(:topic, category: category) }

        include_examples "ordering topics filters", "category", "category name"

        describe "when query string is `order:category` and there are multiple topics in a category" do
          fab!(:topic4) { Fabricate(:topic, category: category) }
          fab!(:topic5) { Fabricate(:topic, category: category2) }

          it "should return topics ordered by category name in descending order and then topic id in ascending order" do
            expect(
              TopicsFilter
                .new(guardian: Guardian.new)
                .filter_from_query_string("order:category")
                .pluck(:id),
            ).to eq([topic2.id, topic.id, topic5.id, topic3.id, topic4.id])
          end
        end
      end

      describe "when query string is `order:created order:views`" do
        fab!(:topic) { Fabricate(:topic, created_at: Time.zone.local(2023, 1, 1), views: 2) }
        fab!(:topic2) { Fabricate(:topic, created_at: Time.zone.local(2024, 1, 1), views: 2) }
        fab!(:topic3) { Fabricate(:topic, created_at: Time.zone.local(2024, 1, 1), views: 1) }

        it "should return topics ordered by creation date in descending order and then number of views in descending order" do
          expect(
            TopicsFilter
              .new(guardian: Guardian.new)
              .filter_from_query_string("order:created order:views")
              .pluck(:id),
          ).to eq([topic2.id, topic3.id, topic.id])
        end
      end
    end
  end
end
