# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'StalledWiki' do
  fab!(:topic_1) { Fabricate(:topic) }
  fab!(:automation) { Fabricate(:automation, trigger: DiscourseAutomation::Triggerable::STALLED_WIKI) }
  fab!(:post_creator_1) { Fabricate(:user, admin: true) }
  let!(:post) {
    post_creator = PostCreator.new(
      post_creator_1,
      topic_id: topic_1.id,
      raw: 'this is a post that will become a wiki'
    )
    post_creator.create
  }

  context 'default' do
    before do
      automation.upsert_field!('stalled_after', 'choices', { value: 'PT10H' }, target: 'trigger')
      automation.upsert_field!('retriggered_after', 'choices', { value: 'PT1H' }, target: 'trigger')
    end

    context 'post has been revised recently' do
      it 'doesn’t trigger' do
        post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 40.minutes.ago })

        output = capture_stdout do
          Jobs::StalledWikiTracker.new.execute(nil)
        end

        expect(output).to_not include('"kind":"stalled_wiki"')
      end
    end

    context 'post hasn’t been revised recently' do
      it 'triggers' do
        post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 1.month.ago })

        output = capture_stdout do
          Jobs::StalledWikiTracker.new.execute(nil)
        end

        expect(output).to include('"kind":"stalled_wiki"')
      end

      context 'trigger has a category' do
        before do
          automation.upsert_field!('stalled_after', 'choices', { value: 'PT10H' }, target: 'trigger')
          automation.upsert_field!('retriggered_after', 'choices', { value: 'PT1H' }, target: 'trigger')
          automation.upsert_field!('restricted_category', 'category', { value: Category.last.id }, target: 'trigger')
        end

        context 'the post is in this category' do
          before do
            post.topic.update(category: Category.last)
          end

          it 'triggers' do
            post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 1.month.ago })

            output = capture_stdout do
              Jobs::StalledWikiTracker.new.execute(nil)
            end

            expect(output).to include('"kind":"stalled_wiki"')
          end
        end

        context 'the post is not in this category' do
          it 'doesn’t trigger' do
            post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 40.minutes.ago })

            output = capture_stdout do
              Jobs::StalledWikiTracker.new.execute(nil)
            end

            expect(output).to_not include('"kind":"stalled_wiki"')
          end
        end
      end

      context 'trigger hasn’t been running recently' do
        before do
          freeze_time 2.hours.from_now
        end

        it 'sets custom field' do
          expect(post.reload.custom_fields['stalled_wiki_triggered_at']).to eq(nil)

          post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 1.month.ago })
          capture_stdout do
            Jobs::StalledWikiTracker.new.execute(nil)
          end

          expect(post.reload.custom_fields['stalled_wiki_triggered_at']).to eq(Time.zone.now.to_s)
        end

        it 'triggers again' do
          post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 2.months.ago })
          post.upsert_custom_fields(stalled_wiki_triggered_at: 2.months.ago)

          output = capture_stdout do
            Jobs::StalledWikiTracker.new.execute(nil)
          end

          expect(output).to include('"kind":"stalled_wiki"')
          expect(post.reload.custom_fields['stalled_wiki_triggered_at']).to eq(Time.zone.now.to_s)
        end
      end

      context 'trigger has been running recently' do
        before do
          freeze_time 2.hours.from_now
        end

        it 'doesn’t trigger again' do
          post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 1.month.ago })
          post.upsert_custom_fields(stalled_wiki_triggered_at: 10.minutes.ago)

          output = capture_stdout do
            Jobs::StalledWikiTracker.new.execute(nil)
          end

          expect(output).to_not include('"kind":"stalled_wiki"')
          expect(post.reload.custom_fields['stalled_wiki_triggered_at']).to eq(10.minutes.ago.to_s)
        end
      end
    end
  end
end
