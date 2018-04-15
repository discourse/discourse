require 'rails_helper'

RSpec.describe TopicsController do
  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:user) }

  describe '#update' do
    it "won't allow us to update a topic when we're not logged in" do
      put "/t/1.json", params: { slug: 'xyz' }
      expect(response.status).to eq(403)
    end

    describe 'when logged in' do
      let(:topic) { Fabricate(:topic, user: user) }

      before do
        Fabricate(:post, topic: topic)
        sign_in(user)
      end

      it 'can not change category to a disallowed category' do
        category = Fabricate(:category)
        category.set_permissions(staff: :full)
        category.save!

        put "/t/#{topic.id}.json", params: { category_id: category.id }

        expect(response.status).not_to eq(200)
        expect(topic.category_id).not_to eq(category.id)
      end

      describe 'without permission' do
        it "raises an exception when the user doesn't have permission to update the topic" do
          topic.update!(archived: true)
          put "/t/#{topic.slug}/#{topic.id}.json"

          expect(response.status).to eq(403)
        end
      end

      describe 'with permission' do
        it 'succeeds' do
          put "/t/#{topic.slug}/#{topic.id}.json"

          expect(response.status).to eq(200)
          expect(::JSON.parse(response.body)['basic_topic']).to be_present
        end

        it "can update a topic to an uncategorized topic" do
          topic.update!(category: Fabricate(:category))

          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            category_id: ""
          }

          expect(response.status).to eq(200)
          expect(topic.reload.category_id).to eq(SiteSetting.uncategorized_category_id)
        end

        it 'allows a change of title' do
          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            title: 'This is a new title for the topic'
          }

          topic.reload
          expect(topic.title).to eq('This is a new title for the topic')
        end

        it "returns errors with invalid titles" do
          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            title: 'asdf'
          }

          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)['errors']).to be_present
        end

        it "returns errors when the rate limit is exceeded" do
          EditRateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            title: 'This is a new title for the topic'
          }

          expect(response.status).to eq(429)
        end

        it "returns errors with invalid categories" do
          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            category_id: -1
          }

          expect(response.status).to eq(422)
        end

        it "doesn't call the PostRevisor when there is no changes" do
          PostRevisor.any_instance.expects(:revise!).never

          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            category_id: topic.category_id
          }

          expect(response.status).to eq(200)
        end

        context 'when topic is private' do
          before do
            topic.update!(
              archetype: Archetype.private_message,
              category: nil,
              allowed_users: [topic.user]
            )
          end

          context 'when there are no changes' do
            it 'does not call the PostRevisor' do
              PostRevisor.any_instance.expects(:revise!).never

              put "/t/#{topic.slug}/#{topic.id}.json", params: {
                category_id: topic.category_id
              }

              expect(response.status).to eq(200)
            end
          end
        end

        context "allow_uncategorized_topics is false" do
          before do
            SiteSetting.allow_uncategorized_topics = false
          end

          it "can add a category to an uncategorized topic" do
            category = Fabricate(:category)

            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              category_id: category.id
            }

            expect(response.status).to eq(200)
            expect(topic.reload.category).to eq(category)
          end
        end
      end
    end
  end

  describe '#show' do
    let(:private_topic) { Fabricate(:private_message_topic) }

    describe 'when topic is not allowed' do
      it 'should return the right response' do
        sign_in(user)

        get "/t/#{private_topic.id}.json"

        expect(response.status).to eq(403)
        expect(response.body).to eq(I18n.t('invalid_access'))
      end
    end
  end

  describe '#timings' do
    let(:post_1) { Fabricate(:post, topic: topic) }

    it 'should record the timing' do
      sign_in(user)

      post "/topics/timings.json", params: {
        topic_id: topic.id,
        topic_time: 5,
        timings: { post_1.post_number => 2 }
      }

      expect(response).to be_success

      post_timing = PostTiming.first

      expect(post_timing.topic).to eq(topic)
      expect(post_timing.user).to eq(user)
      expect(post_timing.msecs).to eq(2)
    end
  end

  describe '#timer' do
    context 'when a user is not logged in' do
      it 'should return the right response' do
        post "/t/#{topic.id}/timer.json", params: {
          time: '24',
          status_type: TopicTimer.types[1]
        }
        expect(response.status).to eq(403)
      end
    end

    context 'when does not have permission' do
      it 'should return the right response' do
        sign_in(user)

        post "/t/#{topic.id}/timer.json", params: {
          time: '24',
          status_type: TopicTimer.types[1]
        }

        expect(response.status).to eq(403)
        expect(JSON.parse(response.body)["error_type"]).to eq('invalid_access')
      end
    end

    context 'when logged in as an admin' do
      let(:admin) { Fabricate(:admin) }

      before do
        sign_in(admin)
      end

      it 'should be able to create a topic status update' do
        post "/t/#{topic.id}/timer.json", params: {
          time: 24,
          status_type: TopicTimer.types[1]
        }

        expect(response).to be_success

        topic_status_update = TopicTimer.last

        expect(topic_status_update.topic).to eq(topic)

        expect(topic_status_update.execute_at)
          .to be_within(1.second).of(24.hours.from_now)

        json = JSON.parse(response.body)

        expect(DateTime.parse(json['execute_at']))
          .to be_within(1.seconds).of(DateTime.parse(topic_status_update.execute_at.to_s))

        expect(json['duration']).to eq(topic_status_update.duration)
        expect(json['closed']).to eq(topic.reload.closed)
      end

      it 'should be able to delete a topic status update' do
        Fabricate(:topic_timer, topic: topic)

        post "/t/#{topic.id}/timer.json", params: {
          time: nil,
          status_type: TopicTimer.types[1]
        }

        expect(response).to be_success
        expect(topic.reload.public_topic_timer).to eq(nil)

        json = JSON.parse(response.body)

        expect(json['execute_at']).to eq(nil)
        expect(json['duration']).to eq(nil)
        expect(json['closed']).to eq(topic.closed)
      end

      describe 'publishing topic to category in the future' do
        it 'should be able to create the topic status update' do
          SiteSetting.queue_jobs = true

          post "/t/#{topic.id}/timer.json", params: {
            time: 24,
            status_type: TopicTimer.types[3],
            category_id: topic.category_id
          }

          expect(response).to be_success

          topic_status_update = TopicTimer.last

          expect(topic_status_update.topic).to eq(topic)

          expect(topic_status_update.execute_at)
            .to be_within(1.second).of(24.hours.from_now)

          expect(topic_status_update.status_type)
            .to eq(TopicTimer.types[:publish_to_category])

          json = JSON.parse(response.body)

          expect(json['category_id']).to eq(topic.category_id)
        end
      end

      describe 'invalid status type' do
        it 'should raise the right error' do
          post "/t/#{topic.id}/timer.json", params: {
            time: 10,
            status_type: 'something'
          }
          expect(response.status).to eq(400)
          expect(response.body).to include('status_type')
        end
      end
    end
  end

  describe '#invite' do
    describe 'when not logged in' do
      it "should return the right response" do
        post "/t/#{topic.id}/invite.json", params: {
          email: 'jake@adventuretime.ooo'
        }

        expect(response.status).to eq(403)
      end
    end

    describe 'when logged in' do
      before do
        sign_in(user)
      end

      describe 'as a valid user' do
        let(:topic) { Fabricate(:topic, user: user) }

        it 'should return the right response' do
          user.update!(trust_level: TrustLevel[2])

          expect do
            post "/t/#{topic.id}/invite.json", params: {
              email: 'someguy@email.com'
            }
          end.to change { Invite.where(invited_by_id: user.id).count }.by(1)

          expect(response.status).to eq(200)
        end
      end

      describe 'when user is a group manager' do
        let(:group) { Fabricate(:group).tap { |g| g.add_owner(user) } }
        let(:private_category)  { Fabricate(:private_category, group: group) }

        let(:group_private_topic) do
          Fabricate(:topic, category: private_category, user: user)
        end

        let(:recipient) { 'jake@adventuretime.ooo' }

        it "should attach group to the invite" do

          post "/t/#{group_private_topic.id}/invite.json", params: {
            user: recipient
          }

          expect(response.status).to eq(200)
          expect(Invite.find_by(email: recipient).groups).to eq([group])
        end
      end

      describe 'when topic id is invalid' do
        it 'should return the right response' do
          post "/t/999/invite.json", params: {
            email: Fabricate(:user).email
          }

          expect(response.status).to eq(400)
        end
      end

      it 'requires an email parameter' do
        post "/t/#{topic.id}/invite.json"
        expect(response.status).to eq(400)
      end

      describe 'when user does not have permission to invite to the topic' do
        let(:topic) { Fabricate(:private_message_topic) }

        it "should return the right response" do
          post "/t/#{topic.id}/invite.json", params: {
            user: user.username
          }

          expect(response.status).to eq(403)
        end
      end
    end

    describe "when inviting a group to a topic" do
      let(:group) { Fabricate(:group) }

      before do
        sign_in(Fabricate(:admin))
      end

      it "should work correctly" do
        email = 'hiro@from.heros'

        post "/t/#{topic.id}/invite.json", params: {
          email: email, group_ids: group.id
        }

        expect(response.status).to eq(200)

        groups = Invite.find_by(email: email).groups
        expect(groups.count).to eq(1)
        expect(groups.first.id).to eq(group.id)
      end
    end
  end

  describe 'invite_group' do
    let(:admins) { Group[:admins] }
    let(:pm) { Fabricate(:private_message_topic) }

    def invite_group(topic, expected_status)
      post "/t/#{topic.id}/invite-group.json", params: { group: admins.name }
      expect(response.status).to eq(expected_status)
    end

    before do
      admins.update!(messageable_level: Group::ALIAS_LEVELS[:everyone])
    end

    describe 'as an anon user' do
      it 'should be forbidden' do
        invite_group(pm, 403)
      end
    end

    describe 'as a normal user' do
      let!(:user) { sign_in(Fabricate(:user)) }

      describe 'when user does not have permission to view the topic' do
        it 'should be forbidden' do
          invite_group(pm, 403)
        end
      end

      describe 'when user has permission to view the topic' do
        before do
          pm.allowed_users << user
        end

        it 'should allow user to invite group to topic' do
          invite_group(pm, 200)
          expect(pm.allowed_groups.first.id).to eq(admins.id)
        end
      end
    end

    describe 'as an admin user' do
      let!(:admin) { sign_in(Fabricate(:admin)) }

      it "disallows inviting a group to a topic" do
        topic = Fabricate(:topic)
        invite_group(topic, 422)
      end

      it "allows inviting a group to a PM" do
        invite_group(pm, 200)
        expect(pm.allowed_groups.first.id).to eq(admins.id)
      end
    end
  end

  describe 'shared drafts' do
    let(:shared_drafts_category) { Fabricate(:category) }
    let(:category) { Fabricate(:category) }

    before do
      SiteSetting.shared_drafts_category = shared_drafts_category.id
    end

    describe "#update_shared_draft" do
      let(:other_cat) { Fabricate(:category) }
      let(:category) { Fabricate(:category) }
      let(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }

      context "anonymous" do
        it "doesn't allow staff to update the shared draft" do
          put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
          expect(response.code.to_i).to eq(403)
        end
      end

      context "as a moderator" do
        let(:moderator) { Fabricate(:moderator) }
        before do
          sign_in(moderator)
        end

        context "with a shared draft" do
          let!(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: category) }
          it "allows staff to update the category id" do
            put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
            expect(response).to be_success
            topic.reload
            expect(topic.shared_draft.category_id).to eq(other_cat.id)
          end
        end

        context "without a shared draft" do
          it "allows staff to update the category id" do
            put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
            expect(response).to be_success
            topic.reload
            expect(topic.shared_draft.category_id).to eq(other_cat.id)
          end
        end
      end
    end

    describe "#publish" do
      let(:category) { Fabricate(:category) }
      let(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }
      let(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: category) }
      let(:moderator) { Fabricate(:moderator) }

      it "fails for anonymous users" do
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
        expect(response.status).to eq(403)
      end

      it "fails as a regular user" do
        sign_in(Fabricate(:user))
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
        expect(response.status).to eq(403)
      end

      context "as staff" do
        before do
          sign_in(moderator)
        end

        it "will publish the topic" do
          put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
          expect(response.status).to eq(200)
          json = ::JSON.parse(response.body)['basic_topic']

          result = Topic.find(json['id'])
          expect(result.category_id).to eq(category.id)
          expect(result.visible).to eq(true)
        end
      end
    end
  end

  describe "crawler" do

    context "when not a crawler" do
      it "renders with the application layout" do
        get topic.url

        body = response.body

        expect(body).to have_tag(:script, with: { src: '/assets/application.js' })
        expect(body).to have_tag(:meta, with: { name: 'fragment' })
      end
    end

    context "when a crawler" do
      it "renders with the crawler layout, and handles proper pagination" do

        page1_time = 3.months.ago
        page2_time = 2.months.ago
        page3_time = 1.month.ago

        freeze_time page1_time

        topic = Fabricate(:topic)
        Fabricate(:post, topic_id: topic.id)
        Fabricate(:post, topic_id: topic.id)

        freeze_time page2_time
        Fabricate(:post, topic_id: topic.id)
        Fabricate(:post, topic_id: topic.id)

        freeze_time page3_time
        Fabricate(:post, topic_id: topic.id)

        # ugly, but no inteface to set this and we don't want to create
        # 100 posts to test this thing
        TopicView.stubs(:chunk_size).returns(2)

        user_agent = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

        get topic.url, env: { "HTTP_USER_AGENT" => user_agent }

        body = response.body

        expect(body).to have_tag(:body, with: { class: 'crawler' })
        expect(body).to_not have_tag(:meta, with: { name: 'fragment' })
        expect(body).to include('<link rel="next" href="' + topic.relative_url + "?page=2")

        expect(response.headers['Last-Modified']).to eq(page1_time.httpdate)

        get topic.url + "?page=2", env: { "HTTP_USER_AGENT" => user_agent }
        body = response.body

        expect(response.headers['Last-Modified']).to eq(page2_time.httpdate)

        expect(body).to include('<link rel="prev" href="' + topic.relative_url)
        expect(body).to include('<link rel="next" href="' + topic.relative_url + "?page=3")

        get topic.url + "?page=3", env: { "HTTP_USER_AGENT" => user_agent }
        body = response.body

        expect(response.headers['Last-Modified']).to eq(page3_time.httpdate)
        expect(body).to include('<link rel="prev" href="' + topic.relative_url + "?page=2")
      end
    end

  end

end
