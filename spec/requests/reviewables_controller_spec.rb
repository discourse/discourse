# frozen_string_literal: true

require 'rails_helper'

describe ReviewablesController do

  context "anonymous" do
    it "denies listing" do
      get "/review.json"
      expect(response.code).to eq("403")
    end

    it "denies performing" do
      put "/review/123/perform/approve.json"
      expect(response.code).to eq("403")
    end

    it "denies settings" do
      get "/review/settings.json"
      expect(response.code).to eq("403")
    end

    it "denies deleting" do
      delete "/review/123"
      expect(response.code).to eq("403")
    end
  end

  context "regular user" do
    before do
      sign_in(Fabricate(:user))
    end

    it "does not allow settings" do
      get "/review/settings.json"
      expect(response.code).to eq("403")
    end
  end

  context "when logged in" do
    fab!(:admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
    end

    context "#index" do
      it "returns empty JSON when nothing to review" do
        get "/review.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to eq([])
      end

      it "returns JSON with reviewable content" do
        reviewable = Fabricate(:reviewable)

        get "/review.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_present

        json_review = json['reviewables'][0]
        expect(json_review['id']).to eq(reviewable.id)
        expect(json_review['created_by_id']).to eq(reviewable.created_by_id)
        expect(json_review['status']).to eq(Reviewable.statuses[:pending])
        expect(json_review['type']).to eq('ReviewableUser')
        expect(json_review['target_created_by_id']).to eq(reviewable.target_created_by_id)
        expect(json_review['score']).to eq(reviewable.score)
        expect(json_review['version']).to eq(reviewable.version)

        expect(json['users'].any? { |u| u['id'] == reviewable.created_by_id }).to eq(true)
        expect(json['users'].any? { |u| u['id'] == reviewable.target_created_by_id }).to eq(true)

        expect(json['meta']['reviewable_count']).to eq(1)
        expect(json['meta']['status']).to eq("pending")
      end

      it "supports filtering by score" do
        get "/review.json?min_score=1000"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_blank
      end

      it "supports offsets" do
        get "/review.json?offset=100"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_blank
      end

      it "supports filtering by type" do
        Fabricate(:reviewable)
        get "/review.json?type=ReviewableUser"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_present
      end

      it "raises an error with an invalid type" do
        get "/review.json?type=ReviewableMadeUp"
        expect(response.code).to eq("500")
      end

      it "supports filtering by status" do
        Fabricate(:reviewable, status: Reviewable.statuses[:approved])

        get "/review.json?type=ReviewableUser&status=pending"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_blank

        Fabricate(:reviewable, status: Reviewable.statuses[:approved])
        get "/review.json?type=ReviewableUser&status=approved"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_present

        get "/review.json?type=ReviewableUser&status=reviewed"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_present

        get "/review.json?type=ReviewableUser&status=all"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_present
      end

      it "raises an error with an invalid status" do
        get "/review.json?status=xyz"
        expect(response.code).to eq("500")
      end

      it "supports filtering by category_id" do
        other_category = Fabricate(:category)
        r = Fabricate(:reviewable)
        get "/review.json?category_id=#{other_category.id}"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_blank

        get "/review.json?category_id=#{r.category_id}"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_present

        # By default all categories are returned
        get "/review.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_present
      end

      it "will use the ReviewableUser serializer for its fields" do
        Jobs.run_immediately!
        SiteSetting.must_approve_users = true
        user = Fabricate(:user)
        user.activate
        reviewable = ReviewableUser.find_by(target: user)

        get "/review.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)

        json_review = json['reviewables'][0]
        expect(json_review['id']).to eq(reviewable.id)
        expect(json_review['user_id']).to eq(user.id)
      end

      context "supports filtering by range" do
        let(:from) { 3.days.ago.strftime('%F') }
        let(:to) { 1.day.ago.strftime('%F') }

        let(:reviewables) { ::JSON.parse(response.body)['reviewables'] }

        it 'returns an empty array when no reviewable matches the date range' do
          reviewable = Fabricate(:reviewable)

          get "/review.json?from_date=#{from}&to_date=#{to}"

          expect(reviewables).to eq([])
        end

        it 'returns reviewable content that matches the date range' do
          reviewable = Fabricate(:reviewable, created_at: 2.day.ago)

          get "/review.json?from_date=#{from}&to_date=#{to}"

          json_review = reviewables.first
          expect(json_review['id']).to eq(reviewable.id)
        end
      end
    end

    context "#show" do
      context "basics" do
        fab!(:reviewable) { Fabricate(:reviewable) }
        before do
          sign_in(Fabricate(:moderator))
        end

        it "returns the reviewable as json" do
          get "/review/#{reviewable.id}.json"
          expect(response.code).to eq("200")

          json = ::JSON.parse(response.body)
          expect(json['reviewable']['id']).to eq(reviewable.id)
        end

        it "returns 404 for a missing reviewable" do
          get "/review/123456789.json"
          expect(response.code).to eq("404")
        end
      end

      context "conversation" do
        fab!(:post) { Fabricate(:post) }
        fab!(:user) { Fabricate(:user) }
        fab!(:admin) { Fabricate(:admin) }
        let(:result) { PostActionCreator.notify_moderators(user, post, 'this is the first post') }
        let(:reviewable) { result.reviewable }

        before do
          PostCreator.create(
            admin,
            topic_id: result.reviewable_score.meta_topic_id,
            raw: "this is the second post"
          )
          PostCreator.create(
            admin,
            topic_id: result.reviewable_score.meta_topic_id,
            raw: "this is the third post"
          )
        end

        it "returns the conversation" do
          get "/review/#{reviewable.id}.json"
          expect(response.code).to eq("200")
          json = ::JSON.parse(response.body)

          score = json['reviewable_scores'][0]
          conversation_id = score['reviewable_conversation_id']

          conversation = json['reviewable_conversations'].find { |c| c['id'] == conversation_id }
          expect(conversation).to be_present
          expect(conversation['has_more']).to eq(true)
          expect(conversation['permalink']).to be_present

          reply = json['conversation_posts'].find { |cp| cp['id'] == conversation['conversation_post_ids'][0] }
          expect(reply['excerpt']).to be_present
          expect(reply['user_id']).to eq(user.id)

          reply = json['conversation_posts'].find { |cp| cp['id'] == conversation['conversation_post_ids'][1] }
          expect(reply['excerpt']).to be_present
          expect(reply['user_id']).to eq(admin.id)
        end

      end
    end

    context "#explain" do
      context "basics" do
        fab!(:reviewable) { Fabricate(:reviewable) }

        before do
          sign_in(Fabricate(:moderator))
        end

        it "returns the explanation as json" do
          get "/review/#{reviewable.id}/explain.json"
          expect(response.code).to eq("200")

          json = ::JSON.parse(response.body)
          expect(json['reviewable_explanation']['id']).to eq(reviewable.id)
          expect(json['reviewable_explanation']['total_score']).to eq(reviewable.score)
        end

        it "returns 404 for a missing reviewable" do
          get "/review/123456789/explain.json"
          expect(response.code).to eq("404")
        end
      end
    end

    context "#perform" do
      fab!(:reviewable) { Fabricate(:reviewable) }
      before do
        sign_in(Fabricate(:moderator))
      end

      it "returns 404 when the reviewable does not exist" do
        put "/review/12345/perform/approve_user.json?version=0"
        expect(response.code).to eq("404")
      end

      it "validates the presenece of an action" do
        put "/review/#{reviewable.id}/perform/nope.json?version=#{reviewable.version}"
        expect(response.code).to eq("403")
      end

      it "ensures the user can see the reviewable" do
        reviewable.update_column(:reviewable_by_moderator, false)
        put "/review/#{reviewable.id}/perform/approve_user.json?version=#{reviewable.version}"
        expect(response.code).to eq("404")
      end

      it "can properly return errors" do
        qp = Fabricate(:reviewable_queued_post_topic, topic_id: -100)
        version = qp.version
        put "/review/#{qp.id}/perform/approve_post.json?version=#{version}"
        expect(response.code).to eq("422")
        result = ::JSON.parse(response.body)
        expect(result['errors']).to be_present
        expect(qp.reload.version).to eq(version)
      end

      it "requires a version parameter" do
        put "/review/#{reviewable.id}/perform/approve_user.json"
        expect(response.code).to eq("422")
        result = ::JSON.parse(response.body)
        expect(result['errors']).to be_present
      end

      it "succeeds for a valid action" do
        other_reviewable = Fabricate(:reviewable)

        put "/review/#{reviewable.id}/perform/approve_user.json?version=#{reviewable.version}"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewable_perform_result']['success']).to eq(true)
        expect(json['reviewable_perform_result']['version']).to eq(1)
        expect(json['reviewable_perform_result']['transition_to']).to eq('approved')
        expect(json['reviewable_perform_result']['transition_to_id']).to eq(Reviewable.statuses[:approved])
        expect(json['reviewable_perform_result']['remove_reviewable_ids']).to eq([reviewable.id])
        expect(json['reviewable_perform_result']['reviewable_count']).to eq(1)

        expect(reviewable.reload.version).to eq(1)
        expect(other_reviewable.reload.version).to eq(0)
      end

      context "claims" do
        fab!(:qp) { Fabricate(:reviewable_queued_post) }

        it "fails when reviewables must be claimed" do
          SiteSetting.reviewable_claiming = 'required'
          put "/review/#{qp.id}/perform/approve_post.json?version=#{qp.version}"
          expect(response.code).to eq("422")
        end

        it "fails when optional claims are claimed by others" do
          SiteSetting.reviewable_claiming = 'optional'
          ReviewableClaimedTopic.create!(topic_id: qp.topic_id, user: Fabricate(:admin))
          put "/review/#{qp.id}/perform/approve_post.json?version=#{qp.version}"
          expect(response.code).to eq("422")
        end

        it "works when claims are optional" do
          SiteSetting.reviewable_claiming = 'optional'
          put "/review/#{qp.id}/perform/approve_post.json?version=#{qp.version}"
          expect(response.code).to eq("200")
        end
      end

      describe "simultaneous perform" do
        it "fails when the version is wrong" do
          put "/review/#{reviewable.id}/perform/approve_user.json?version=#{reviewable.version + 1}"
          expect(response.code).to eq("409")
          json = ::JSON.parse(response.body)
          expect(json['errors']).to be_present
        end
      end
    end

    context "#topics" do
      fab!(:post0) { Fabricate(:post) }
      fab!(:post1) { Fabricate(:post, topic: post0.topic) }
      fab!(:post2) { Fabricate(:post) }
      fab!(:user0) { Fabricate(:user) }
      fab!(:user1) { Fabricate(:user) }

      it "returns empty json for no reviewables" do
        get "/review/topics.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewable_topics']).to be_blank
      end

      it "includes claimed information" do
        SiteSetting.reviewable_claiming = 'optional'
        PostActionCreator.spam(user0, post0)
        moderator = Fabricate(:moderator)
        ReviewableClaimedTopic.create!(user: moderator, topic: post0.topic)

        get "/review/topics.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        json_topic = json['reviewable_topics'].find { |rt| rt['id'] == post0.topic_id }
        expect(json_topic['claimed_by_id']).to eq(moderator.id)

        json_user = json['users'].find { |u| u['id'] == json_topic['claimed_by_id'] }
        expect(json_user).to be_present
      end

      it "returns json listing the topics" do
        PostActionCreator.spam(user0, post0)
        PostActionCreator.off_topic(user0, post1)
        PostActionCreator.spam(user0, post2)
        PostActionCreator.spam(user1, post2)

        get "/review/topics.json"
        expect(response.code).to eq("200")

        json = ::JSON.parse(response.body)
        expect(json['reviewable_topics']).to be_present

        json_topic = json['reviewable_topics'].find { |rt| rt['id'] == post0.topic_id }
        expect(json_topic['stats']['count']).to eq(2)
        expect(json_topic['stats']['unique_users']).to eq(1)

        json_topic = json['reviewable_topics'].find { |rt| rt['id'] == post2.topic_id }
        expect(json_topic['stats']['count']).to eq(2)
        expect(json_topic['stats']['unique_users']).to eq(2)
      end
    end

    context "#settings" do
      it "renders the settings as JSON" do
        get "/review/settings.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewable_settings']).to be_present
        expect(json['reviewable_score_types']).to be_present
      end

      it "allows the settings to be updated" do
        put "/review/settings.json", params: { reviewable_priorities: { 8 => Reviewable.priorities[:medium] } }
        expect(response.code).to eq("200")
        pa = PostActionType.find_by(id: 8)
        expect(pa.reviewable_priority).to eq(Reviewable.priorities[:medium])
        expect(pa.score_bonus).to eq(5.0)

        put "/review/settings.json", params: { reviewable_priorities: { 8 => Reviewable.priorities[:low] } }
        expect(response.code).to eq("200")
        pa = PostActionType.find_by(id: 8)
        expect(pa.reviewable_priority).to eq(Reviewable.priorities[:low])
        expect(pa.score_bonus).to eq(0.0)

        put "/review/settings.json", params: { reviewable_priorities: { 8 => Reviewable.priorities[:high] } }
        expect(response.code).to eq("200")
        pa = PostActionType.find_by(id: 8)
        expect(pa.reviewable_priority).to eq(Reviewable.priorities[:high])
        expect(pa.score_bonus).to eq(10.0)
      end
    end

    context "#update" do
      fab!(:reviewable) { Fabricate(:reviewable) }
      fab!(:reviewable_post) { Fabricate(:reviewable_queued_post) }
      fab!(:reviewable_topic) { Fabricate(:reviewable_queued_post_topic) }
      fab!(:moderator) { Fabricate(:moderator) }

      before do
        sign_in(moderator)
      end

      it "returns 404 when the reviewable does not exist" do
        put "/review/12345.json?version=0"
        expect(response.code).to eq("404")
      end

      it "returns access denied if there are no editable fields" do
        put(
          "/review/#{reviewable.id}.json?version=#{reviewable.version}",
          params: { reviewable: { field: 'value' } }
        )
        expect(response.code).to eq("403")
      end

      it "returns access denied if you try to update a field that doesn't exist" do
        put(
          "/review/#{reviewable_post.id}.json?version=#{reviewable_post.version}",
          params: { reviewable: { field: 'value' } }
        )
        expect(response.code).to eq("403")
      end

      it "requires a version parameter" do
        put "/review/#{reviewable_post.id}.json"
        expect(response.code).to eq("422")
      end

      it "fails if there is a version conflict" do
        put "/review/#{reviewable_post.id}.json?version=#{reviewable_post.version + 2}",
          params: {
            reviewable: {
              payload: {
                raw: 'new raw content'
              }
            }
          }

        expect(response.code).to eq("409")
      end

      it "allows you to update a queued post" do
        put "/review/#{reviewable_post.id}.json?version=#{reviewable_post.version}",
          params: {
            reviewable: {
              payload: {
                raw: 'new raw content'
              }
            }
          }

        expect(response.code).to eq("200")
        reviewable_post.reload
        expect(reviewable_post.payload['raw']).to eq('new raw content')

        history = ReviewableHistory.find_by(
          reviewable_id: reviewable_post.id,
          created_by_id: moderator.id,
          reviewable_history_type: ReviewableHistory.types[:edited]
        )
        expect(history).to be_present

        json = ::JSON.parse(response.body)
        expect(json['payload']['raw']).to eq('new raw content')
        expect(json['version'] > 0).to eq(true)
      end

      it "allows you to update a queued post (for new topic)" do
        new_category_id = Fabricate(:category).id

        put "/review/#{reviewable_topic.id}.json?version=#{reviewable_topic.version}",
          params: {
            reviewable: {
              payload: {
                raw: 'new topic op',
                title: 'new topic title',
                tags: ['t2', 't3', 't1']
              },
              category_id: new_category_id
            }
          }

        expect(response.code).to eq("200")
        reviewable_topic.reload
        expect(reviewable_topic.payload['raw']).to eq('new topic op')
        expect(reviewable_topic.payload['title']).to eq('new topic title')
        expect(reviewable_topic.payload['extra']).to eq('some extra data')
        expect(reviewable_topic.payload['tags']).to eq(['t2', 't3', 't1'])
        expect(reviewable_topic.category_id).to eq(new_category_id)

        json = ::JSON.parse(response.body)
        expect(json['payload']['raw']).to eq('new topic op')
        expect(json['payload']['title']).to eq('new topic title')
        expect(json['payload']['extra']).to be_blank
        expect(json['category_id']).to eq(new_category_id.to_s)
      end

    end

    context "#destroy" do
      fab!(:user) { Fabricate(:user) }

      before do
        sign_in(user)
      end

      it "returns 404 if the reviewable doesn't exist" do
        delete "/review/1234.json"
        expect(response.code).to eq("404")
      end

      it "returns 404 if the user can't see the reviewable" do
        queued_post = Fabricate(:reviewable_queued_post)
        delete "/review/#{queued_post.id}.json"
        expect(response.code).to eq("404")
      end

      it "returns 200 if the user can delete the reviewable" do
        queued_post = Fabricate(:reviewable_queued_post, created_by: user)
        delete "/review/#{queued_post.id}.json"
        expect(response.code).to eq("200")
        expect(queued_post.reload).to be_deleted
      end
    end

  end

end
