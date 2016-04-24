require 'pp'
require 'rails_helper'

describe TopicPostersSummary do
  describe '#summary' do
    let(:summary) { described_class.new(topic).summary }

    let(:topic) do
      Fabricate(:topic,
                user: topic_creator,
                last_poster: last_poster,
                featured_user1: featured_user1,
                featured_user2: featured_user2,
                featured_user3: featured_user3,
                featured_user4: featured_user4
               )
    end

    let(:topic_creator)  { Fabricate(:user) }
    let(:last_poster)    { nil }
    let(:featured_user1) { nil }
    let(:featured_user2) { nil }
    let(:featured_user3) { nil }
    let(:featured_user4) { nil }

    context "without queued_preview approval" do

      it 'contains only the topic creator when there are no other posters' do
        expect(summary.count).to eq 1

        summary.first.tap do |topic_poster|
          expect(topic_poster.user).to eq topic_creator
          expect(topic_poster.description).to eq(
                                                "#{I18n.t(:original_poster)}, #{I18n.t(:most_recent_poster)}"
                                              )
        end
      end

      context 'when the lastest poster is also the topic creator' do
        let(:last_poster)    { topic_creator }
        let(:featured_user1) { Fabricate(:user) }

        before do
          topic.last_poster = topic_creator
          topic.featured_user1 = featured_user1
          topic.save!
        end

        it 'keeps the topic creator at the front of the summary' do
          expect(summary.map(&:user)).to eq([
                                              topic_creator,
                                              featured_user1
                                            ])
        end
      end

      context 'when the topic has many posters' do
        let(:last_poster)    { Fabricate(:user) }
        let(:featured_user1) { Fabricate(:user) }
        let(:featured_user2) { Fabricate(:user) }
        let(:featured_user3) { Fabricate(:user) }
        let(:featured_user4) { Fabricate(:user) }

        it 'contains only five posters with latest poster at the end' do
          expect(summary.map(&:user)).to eq([
                                              topic_creator,
                                              featured_user1, featured_user2, featured_user3,
                                              last_poster
                                            ])
          # If more than one user, attach the latest class
          expect(summary.last.extras).to eq 'latest'
        end
      end
    end

    context "with queued_preview approval" do
      let(:stranger) { Fabricate(:user) }
      let(:admin)    { Fabricate(:user, admin: true) }
      let(:summary_anon) { described_class.new(topic).summary }
      let(:summary_admin) { described_class.new(topic, user: admin).summary }
      let(:summary_creator) { described_class.new(topic, user: topic_creator).summary }
      let(:summary_stranger) { described_class.new(topic, user: stranger).summary }
      let(:summary_featured1) { described_class.new(topic, user: featured_user1).summary }
      let(:summary_featured2) { described_class.new(topic, user: featured_user2).summary }

      before(:each) do
        SiteSetting.stubs(:queued_preview_mode).returns(true)
        SiteSetting.stubs(:approve_unless_trust_level).returns(4)
      end

      context "contains only the topic creator when there are no other posters" do
        let!(:p1) { Post.create(topic: topic, user: topic_creator, post_number: 1, raw: 'Test post 1') }

        it 'when approved all can see topic creator' do
          expect(summary_admin.count).to eq 1
          expect(summary_creator.count).to eq 1
          expect(summary_stranger.count).to eq 1
          expect(summary_anon.count).to eq 1

          [summary_admin, summary_creator, summary_stranger, summary_anon].each do |summary|
            summary.first.tap do |topic_poster|
              expect(topic_poster.user).to eq topic_creator
              expect(topic_poster.description).to eq("#{I18n.t(:original_poster)}, #{I18n.t(:most_recent_poster)}")
            end
          end
        end # it

        it 'when not approved only creator and staff can see topic creator' do
          QueuedPreviewPostMap.create(post_id: p1.id)

          expect(summary_admin.count).to eq 1
          expect(summary_creator.count).to eq 1
          expect(summary_stranger.count).to eq 0
          expect(summary_anon.count).to eq 0

          [summary_admin, summary_creator].each do |summary|
            summary.first.tap do |topic_poster|
              expect(topic_poster.user).to eq topic_creator
              expect(topic_poster.description).to eq("#{I18n.t(:original_poster)}, #{I18n.t(:most_recent_poster)}")
            end
          end
        end # it
      end

      context "when the lastest poster can be hidden" do
        let(:featured_user1) { Fabricate(:user) }
        let(:featured_user2) { Fabricate(:user) }

        let!(:p1) { Post.create(topic: topic, user: topic_creator, post_number: 1, raw: 'Test post 1') }
        let!(:p2) { Post.create(topic: topic, user: featured_user1, post_number: 2, raw: 'Test post 2') }
        let!(:p3) { Post.create(topic: topic, user: topic_creator, post_number: 3, raw: 'Test post 3') }
        let!(:p4) { Post.create(topic: topic, user: featured_user2, post_number: 4, raw: 'Test post 4') }

        before do
          topic.last_poster = featured_user2
          topic.featured_user1 = featured_user1
          topic.featured_user2 = featured_user2
          topic.save!
        end

        it 'when last post approved all can see actual last poster' do
          [summary_admin, summary_creator, summary_featured1, summary_featured2, summary_stranger, summary_anon].each do |summary|
            expect(summary.map(&:user)).to eq([
                                                topic_creator,
                                                featured_user1,
                                                featured_user2
                                              ])
          end
        end # it

        context 'when last post does not approved' do
          before do
            QueuedPreviewPostMap.create(post_id: p4.id)
          end

          it 'post creator and staff can see actual last poster' do
            [summary_admin, summary_featured2].each do |summary|
              expect(summary.map(&:user)).to eq([
                                                  topic_creator,
                                                  featured_user1,
                                                  featured_user2
                                                ])
            end
          end

          it 'all except post creator and staff can\'t see actual last poster' do
            [summary_creator, summary_featured1, summary_stranger, summary_anon].each do |summary|
              expect(summary.map(&:user)).to eq([
                                                  topic_creator,
                                                  featured_user1
                                                ])
            end
          end

          context 'when some of latest posts do not approved' do
            let!(:p5) { Post.create(topic: topic, user: featured_user1, post_number: 5, raw: 'Test post 5') }

            before do
              QueuedPreviewPostMap.create(post_id: p5.id)
            end

            it 'each poster see only her post and only featured user if he has at least one approved post' do
              expect(summary_featured1.map(&:user)).to eq([
                                                            topic_creator,
                                                            featured_user1
                                                          ])
              expect(summary_featured1.last.extras).to eq 'latest'

              expect(summary_featured2.map(&:user)).to eq([
                                                            topic_creator,
                                                            featured_user1,
                                                            featured_user2
                                                          ])
              expect(summary_featured2.last.extras).to eq 'latest'
            end
          end
        end
      end
    end
  end
end
