# frozen_string_literal: true

require_relative "read_tool_support"

describe DiscourseMcp::Server do
  include McpContentReadHelpers

  shared_examples "restricted notification defaults" do |tool|
    it "#{tool} conceals restricted notification defaults and preserves allowed defaults" do
      denied_category = Fabricate(:category, id: 91_300_001)
      allowed_category = Fabricate(:category, id: 91_300_002)
      denied_tag =
        Fabricate(:tag, id: 91_300_003, name: "cru3-denied-tag", slug: "cru3-denied-slug")
      allowed_tag = Fabricate(:tag, id: 91_300_004, name: "cru3-allowed-tag")
      levels = %i[watching tracking watching_first_post regular muted]
      groups = levels.index_with { Fabricate(:group) }
      groups.each do |level, group|
        [denied_category, allowed_category].each do |category|
          GroupCategoryNotificationDefault.create!(
            group:,
            category:,
            notification_level: NotificationLevels.all.fetch(level),
          )
        end
        [denied_tag, allowed_tag].each do |tag|
          GroupTagNotificationDefault.create!(
            group:,
            tag:,
            notification_level: NotificationLevels.all.fetch(level),
          )
        end
        baseline = group_call(tool, group)
        payloads(baseline).each do |payload|
          expect(payload.fetch("group").fetch("#{level}_category_ids")).to include(
            denied_category.id,
          )
          expect(payload.fetch("group").fetch("#{level}_tags")).to include(
            a_hash_including(
              "id" => denied_tag.id,
              "name" => denied_tag.name,
              "slug" => denied_tag.slug,
            ),
          )
        end
      end

      forum_rule(denied_categories: [denied_category.id], denied_tags: [denied_tag.id])
      aggregate_failures do
        groups.each do |level, group|
          response = group_call(tool, group)
          expect_absent(
            response,
            [denied_category.id, denied_tag.id, denied_tag.name, denied_tag.slug],
            "#{tool} #{level}",
          )
          payloads(response).each do |payload|
            expect(payload.fetch("group").fetch("#{level}_category_ids")).to include(
              allowed_category.id,
            )
            expect(payload.fetch("group").fetch("#{level}_tags")).to include(
              a_hash_including("id" => allowed_tag.id, "name" => allowed_tag.name),
            )
          end
        end
      end
    end
  end

  shared_examples "restricted group message metadata" do |tool|
    it "#{tool} exposes identical message metadata for no messages and a denied-tag message" do
      group = Fabricate(:group)
      denied_tag = Fabricate(:tag)
      forum_rule(denied_tags: [denied_tag.id])
      empty = group_call(tool, group)
      message = Fabricate(:private_message_topic, user: admin)
      Fabricate(:post, topic: message, user: admin)
      message.tags << denied_tag
      message.invite_group(admin, group, should_notify: false)
      group.reload
      expect(group.has_messages).to eq(true)
      expect(group.message_count).to eq(1)

      response = group_call(tool, group)

      aggregate_failures do
        payloads(response)
          .zip(payloads(empty))
          .each do |actual, before|
            %w[has_messages message_count].each do |field|
              expect(actual.fetch("group").slice(field)).to eq(before.fetch("group").slice(field)),
              "#{tool} #{field} distinguishes a restricted message from no messages"
            end
          end
      end
    end
  end

  include_examples "restricted notification defaults", "discourse_get_group"
  include_examples "restricted notification defaults", "discourse_update_group"
  include_examples "restricted group message metadata", "discourse_get_group"
  include_examples "restricted group message metadata", "discourse_update_group"
end
