# frozen_string_literal: true

require "rails_helper"

module DiscourseAi
  module Automation
    describe ReportRunner do
      fab!(:user)
      fab!(:receiver) { Fabricate(:user) }
      fab!(:post) { Fabricate(:post, user: user) }
      fab!(:group)
      fab!(:secure_category) { Fabricate(:private_category, group: group) }
      fab!(:secure_topic) { Fabricate(:topic, category: secure_category) }
      fab!(:secure_post) { Fabricate(:post, raw: "Top secret date !!!!", topic: secure_topic) }

      fab!(:category)
      fab!(:topic_in_category) { Fabricate(:topic, category: category) }
      fab!(:post_in_category) do
        Fabricate(:post, raw: "I am in a category", topic: topic_in_category)
      end

      fab!(:tag)
      fab!(:hidden_tag) { Fabricate(:tag, name: "hidden-tag") }
      fab!(:tag_group) do
        tag_group = TagGroup.new(name: "test tag group")
        tag_group.tag_group_permissions.build(group_id: Group::AUTO_GROUPS[:trust_level_1])

        tag_group.save!
        TagGroupMembership.create!(tag_group_id: tag_group.id, tag_id: hidden_tag.id)
        tag_group
      end
      fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag, hidden_tag]) }
      fab!(:post_with_tag) { Fabricate(:post, raw: "I am in a tag", topic: topic_with_tag) }

      fab!(:llm_model)

      before { enable_current_plugin }

      describe "#run!" do
        it "is able to generate email reports" do
          freeze_time

          DiscourseAi::Completions::Llm.with_prepared_responses(["magical report"]) do
            ReportRunner.run!(
              sender_username: user.username,
              receivers: ["fake@discourse.com"],
              title: "test report %DATE%",
              model: "custom:#{llm_model.id}",
              persona_id:
                DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::ReportRunner],
              category_ids: nil,
              tags: nil,
              allow_secure_categories: false,
              sample_size: 100,
              instructions: "make a magic report",
              days: 7,
              offset: 0,
              priority_group_id: nil,
              tokens_per_post: 150,
              debug_mode: nil,
            )
          end

          expect(ActionMailer::Base.deliveries.length).to eq(1)
          expect(ActionMailer::Base.deliveries.first.subject).to eq(
            "test report #{7.days.ago.strftime("%Y-%m-%d")} - #{Time.zone.now.strftime("%Y-%m-%d")}",
          )
        end

        it "can exclude categories (including sub categories)" do
          subcategory = Fabricate(:category, parent_category_id: category.id)
          topic_in_subcategory = Fabricate(:topic, category: subcategory)
          post_in_subcategory =
            Fabricate(:post, raw: "I am in a subcategory abcd", topic: topic_in_subcategory)

          other_category = Fabricate(:category)
          topic2 = Fabricate(:topic, category: other_category)
          post2 = Fabricate(:post, raw: "I am in another category 123", topic: topic2)

          freeze_time

          DiscourseAi::Completions::Llm.with_prepared_responses(["magical report"]) do
            ReportRunner.run!(
              sender_username: user.username,
              receivers: [receiver.username],
              title: "test report",
              model: "custom:#{llm_model.id}",
              persona_id:
                DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::ReportRunner],
              category_ids: nil,
              tags: nil,
              allow_secure_categories: false,
              debug_mode: true,
              sample_size: 100,
              instructions: "make a magic report",
              days: 7,
              offset: 0,
              priority_group_id: nil,
              tokens_per_post: 150,
              exclude_category_ids: [category.id],
            )
          end

          report = Topic.where(title: "test report").first
          debugging = report.ordered_posts.last.raw

          expect(debugging).not_to include(post_in_category.raw)
          expect(debugging).not_to include(post_in_subcategory.raw)
          expect(debugging).to include(post2.raw)
          expect(debugging).to include(post_with_tag.raw)
          expect(debugging).to include(tag.name)
          expect(debugging).not_to include(hidden_tag.name)
        end

        it "can suppress notifications by remapping content" do
          user = Fabricate(:user)

          markdown = <<~MD
            @#{user.username} is a person
            [test1](/test) is an internal link
            [test2](/test?1=2) is an internal link
            [test3](https://example.com) is an external link
            [test4](#{Discourse.base_url}) is an internal link
            <a href='/test'>test5</a> is an internal link
            [test6](/test?test=test#anchor) is an internal link with fragment
            [test7](//[[test) is a link with an invalid URL
          MD

          DiscourseAi::Completions::Llm.with_prepared_responses([markdown]) do
            ReportRunner.run!(
              sender_username: user.username,
              receivers: [receiver.username],
              title: "test report",
              model: "custom:#{llm_model.id}",
              persona_id:
                DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::ReportRunner],
              category_ids: nil,
              tags: nil,
              allow_secure_categories: false,
              debug_mode: false,
              sample_size: 100,
              instructions: "make a magic report",
              days: 7,
              offset: 0,
              priority_group_id: nil,
              tokens_per_post: 150,
              suppress_notifications: true,
            )
          end

          report = Topic.where(title: "test report").first

          # note, magic surprise &amp; is correct HTML 5 representation
          expected = <<~HTML
            <p><a class="mention" href="/u/#{user.username}">#{user.username}</a> is a person<br>
            <a href="/test?silent=true">test1</a> is an internal link<br>
            <a href="/test?1=2&amp;silent=true">test2</a> is an internal link<br>
            <a href="https://example.com" rel="noopener nofollow ugc">test3</a> is an external link<br>
            <a href="http://test.localhost?silent=true">test4</a> is an internal link<br>
            <a href="/test?silent=true">test5</a> is an internal link<br>
            <a href="/test?test=test&amp;silent=true#anchor">test6</a> is an internal link with fragment<br>
            <a href="//%5B%5Btest?silent=true" rel="noopener nofollow ugc">test7</a> is a link with an invalid URL</p>
          HTML

          post = report.ordered_posts.first

          expect(post.mentions.to_a).to eq([])
          expect(post.raw.strip).to eq(expected.strip)
        end

        it "can exclude tags" do
          freeze_time

          DiscourseAi::Completions::Llm.with_prepared_responses(["magical report"]) do
            ReportRunner.run!(
              sender_username: user.username,
              receivers: [receiver.username],
              title: "test report",
              model: "custom:#{llm_model.id}",
              persona_id:
                DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::ReportRunner],
              category_ids: nil,
              tags: nil,
              allow_secure_categories: false,
              debug_mode: true,
              sample_size: 100,
              instructions: "make a magic report",
              days: 7,
              offset: 0,
              priority_group_id: nil,
              tokens_per_post: 150,
              exclude_tags: [tag.name],
            )
          end

          report = Topic.where(title: "test report").first
          debugging = report.ordered_posts.last.raw

          expect(debugging).to include(post_in_category.raw)
          expect(debugging).not_to include(post_with_tag.raw)
        end

        it "can send reports to groups only" do
          group_for_reports = Fabricate(:group)
          group_member = Fabricate(:user)
          group_for_reports.add(group_member)

          DiscourseAi::Completions::Llm.with_prepared_responses(["group report"]) do
            ReportRunner.run!(
              sender_username: user.username,
              receivers: [group_for_reports.name],
              title: "group report",
              model: "custom:#{llm_model.id}",
              persona_id:
                DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::ReportRunner],
              category_ids: nil,
              tags: nil,
              allow_secure_categories: false,
              debug_mode: false,
              sample_size: 100,
              instructions: "make a group report",
              days: 7,
              offset: 0,
              priority_group_id: nil,
              tokens_per_post: 150,
            )
          end

          report_topic =
            Topic.where(title: "group report", archetype: Archetype.private_message).first
          expect(report_topic).to be_present
          expect(report_topic.allowed_groups.map(&:id)).to eq([group_for_reports.id])
          expect(report_topic.allowed_users.map(&:id)).to eq([user.id])
          expect(report_topic.ordered_posts.first.raw).to eq("group report")
        end

        it "generates correctly respects the params" do
          DiscourseAi::Completions::Llm.with_prepared_responses(["magical report"]) do
            ReportRunner.run!(
              sender_username: user.username,
              receivers: [receiver.username],
              title: "test report",
              model: "custom:#{llm_model.id}",
              persona_id:
                DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::ReportRunner],
              category_ids: nil,
              tags: nil,
              allow_secure_categories: false,
              debug_mode: true,
              sample_size: 100,
              instructions: "make a magic report",
              days: 7,
              offset: 0,
              priority_group_id: nil,
              tokens_per_post: 150,
            )
          end

          report = Topic.where(title: "test report").first
          expect(report.ordered_posts.first.raw).to eq("magical report")
          debugging = report.ordered_posts.last.raw

          expect(debugging).to include(post.raw)
          expect(debugging).to include(post_in_category.raw)
          expect(debugging).to include(post_with_tag.raw)
          expect(debugging).not_to include(secure_post.raw)
        end
      end
    end
  end
end
