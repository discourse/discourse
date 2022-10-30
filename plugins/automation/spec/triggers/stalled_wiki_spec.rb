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

  it "allows manual trigger" do
    triggerable = DiscourseAutomation::Triggerable.new(automation.trigger)
    expect(triggerable.settings[DiscourseAutomation::Triggerable::MANUAL_TRIGGER_KEY]).to eq(true)
  end

  describe 'default' do
    before do
      automation.upsert_field!('stalled_after', 'choices', { value: 'PT10H' }, target: 'trigger')
      automation.upsert_field!('retriggered_after', 'choices', { value: 'PT1H' }, target: 'trigger')
    end

    it "supports manual triggering" do
      DiscourseAutomation::AutomationSerializer.new(
        automation,
        root: 'automation'
      ).as_json
    end

    context 'when the post has been revised recently' do
      it 'doesn’t trigger' do
        post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 40.minutes.ago })

        list = capture_contexts do
          Jobs::StalledWikiTracker.new.execute(nil)
        end

        expect(list.length).to eq(0)
      end
    end

    context 'when the post hasn’t been revised recently' do
      it 'triggers' do
        post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 1.month.ago })

        list = capture_contexts do
          Jobs::StalledWikiTracker.new.execute(nil)
        end

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq('stalled_wiki')
      end

      context 'when trigger has a category' do
        fab!(:category) { Fabricate(:category) }

        before do
          automation.upsert_field!('stalled_after', 'choices', { value: 'PT10H' }, target: 'trigger')
          automation.upsert_field!('retriggered_after', 'choices', { value: 'PT1H' }, target: 'trigger')
          automation.upsert_field!('restricted_category', 'category', { value: category.id }, target: 'trigger')
        end

        context 'when the post is in a sub category' do
          before do
            subcategory = Fabricate(:category, parent_category: category)
            subcategory.save!

            post.topic.update(category: subcategory)
          end

          it 'doesn’t trigger' do
            post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 40.minutes.ago })

            list = capture_contexts do
              Jobs::StalledWikiTracker.new.execute(nil)
            end

            expect(list).to be_empty
          end
        end

        context 'when the post is in this category' do
          before do
            post.topic.update(category: category)
          end

          it 'triggers' do
            post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 1.month.ago })

            list = capture_contexts do
              Jobs::StalledWikiTracker.new.execute(nil)
            end

            expect(list.length).to eq(1)
            expect(list[0]["kind"]).to eq('stalled_wiki')
          end
        end

        context 'when the post is not in this category' do
          it 'doesn’t trigger' do
            post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 40.minutes.ago })

            list = capture_contexts do
              Jobs::StalledWikiTracker.new.execute(nil)
            end

            expect(list).to be_empty
          end
        end
      end

      context 'when trigger hasn’t been running recently' do
        before do
          freeze_time 2.hours.from_now
        end

        it 'sets custom field' do
          expect(post.reload.custom_fields['stalled_wiki_triggered_at']).to eq(nil)

          post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 1.month.ago })
          Jobs::StalledWikiTracker.new.execute(nil)

          expect(post.reload.custom_fields['stalled_wiki_triggered_at']).to eq(Time.zone.now.to_s)
        end

        it 'triggers again' do
          post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 2.months.ago })
          post.upsert_custom_fields(stalled_wiki_triggered_at: 2.months.ago)

          list = capture_contexts do
            Jobs::StalledWikiTracker.new.execute(nil)
          end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("stalled_wiki")
          expect(post.reload.custom_fields['stalled_wiki_triggered_at']).to eq(Time.zone.now.to_s)
        end
      end

      context 'when trigger has been running recently' do
        before do
          freeze_time 2.hours.from_now
        end

        it 'doesn’t trigger again' do
          post.revise(post_creator_1, { wiki: true }, { force_new_version: true, revised_at: 1.month.ago })
          post.upsert_custom_fields(stalled_wiki_triggered_at: 10.minutes.ago)

          list = capture_contexts do
            Jobs::StalledWikiTracker.new.execute(nil)
          end

          expect(list.length).to eq(0)
          expect(post.reload.custom_fields['stalled_wiki_triggered_at']).to eq(10.minutes.ago.to_s)
        end
      end
    end
  end
end
