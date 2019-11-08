# frozen_string_literal: true

require 'rails_helper'

describe Badge do
  it { is_expected.to belong_to(:badge_type) }
  it { is_expected.to belong_to(:badge_grouping) }
  it { is_expected.to have_many(:user_badges).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:badge_type) }
  it { is_expected.to validate_uniqueness_of(:name) }

  it 'has a valid system attribute for new badges' do
    expect(Badge.create!(name: "test", badge_type_id: 1).system?).to be false
  end

  it 'auto translates name' do
    badge = Badge.find_by_name("Basic User")
    name_english = badge.name

    I18n.with_locale(:fr) do
      expect(badge.display_name).not_to eq(name_english)
    end
  end

  it 'handles changes on badge description and long description correctly for system badges' do
    badge = Badge.find_by_name("Basic User")
    badge.description = badge.description.dup
    badge.long_description = badge.long_description.dup
    badge.save
    badge.reload

    expect(badge[:description]).to eq(nil)
    expect(badge[:long_description]).to eq(nil)

    badge.description = "testing"
    badge.long_description = "testing it"

    badge.save
    badge.reload

    expect(badge[:description]).to eq("testing")
    expect(badge[:long_description]).to eq("testing it")
  end

  it 'can ensure consistency' do
    b = Badge.first
    b.grant_count = 100
    b.save

    UserBadge.create!(user_id: -100, badge_id: b.id, granted_at: 1.minute.ago, granted_by_id: -1)
    UserBadge.create!(user_id: User.first.id, badge_id: b.id, granted_at: 1.minute.ago, granted_by_id: -1)

    Badge.ensure_consistency!

    b.reload
    expect(b.grant_count).to eq(1)
  end

  describe '#manually_grantable?' do
    fab!(:badge) { Fabricate(:badge, name: 'Test Badge') }
    subject { badge.manually_grantable? }

    context 'when system badge' do
      before { badge.system = true }
      it { is_expected.to be false }
    end

    context 'when has query' do
      before { badge.query = 'SELECT id FROM users' }
      it { is_expected.to be false }
    end

    context 'when neither system nor has query' do
      before { badge.update_columns(system: false, query: nil) }
      it { is_expected.to be true }
    end
  end

  describe '.i18n_name' do
    it 'transforms to lower case letters, and replaces spaces with underscores' do
      expect(Badge.i18n_name('Basic User')).to eq('basic_user')
    end
  end

  describe '.display_name' do
    it 'fetches from translations when i18n_name key exists' do
      expect(Badge.display_name('basic_user')).to eq('Basic')
      expect(Badge.display_name('Basic User')).to eq('Basic')
    end

    it 'fallbacks to argument value when translation does not exist' do
      expect(Badge.display_name('Not In Translations')).to eq('Not In Translations')
    end
  end

  describe '.find_system_badge_id_from_translation_key' do
    let(:translation_key) { 'badges.regular.name' }

    it 'uses a translation key to get a system badge id, mainly to find which badge a translation override corresponds to' do
      expect(Badge.find_system_badge_id_from_translation_key(translation_key)).to eq(
        Badge::Regular
      )
    end

    context 'when the translation key is snake case' do
      let(:translation_key) { 'badges.crazy_in_love.name' }

      it 'works to get the badge' do
        expect(Badge.find_system_badge_id_from_translation_key(translation_key)).to eq(
          Badge::CrazyInLove
        )
      end
    end

    context 'when a translation key not for a badge is provided' do
      let(:translation_key) { 'reports.flags.title' }
      it 'returns nil' do
        expect(Badge.find_system_badge_id_from_translation_key(translation_key)).to eq(nil)
      end
    end
  end

  context "First Quote" do
    let(:quoted_post_badge) do
      Badge.find(Badge::FirstQuote)
    end

    it "Awards at the correct award date" do
      freeze_time
      post1 = create_post

      raw = <<~RAW
        [quote="#{post1.user.username}, post:#{post1.post_number}, topic:#{post1.topic_id}"]
        lorem
        [/quote]
      RAW

      post2 = create_post(raw: raw)

      quoted_post = QuotedPost.find_by(post_id: post2.id)
      freeze_time 1.year.from_now
      quoted_post.update!(created_at: Time.now)

      BadgeGranter.backfill(quoted_post_badge)
      user_badge = post2.user.user_badges.find_by(badge_id: quoted_post_badge.id)

      expect(user_badge.granted_at).to eq_time(post2.created_at)

    end
  end

  context "PopularLink badge" do

    let(:popular_link_badge) do
      Badge.find(Badge::PopularLink)
    end

    before do
      popular_link_badge.query = BadgeQueries.linking_badge(2)
      popular_link_badge.save!
    end

    it "is awarded" do
      post = create_post(raw: "https://www.discourse.org/")

      TopicLinkClick.create_from(url: "https://www.discourse.org/", post_id: post.id, topic_id: post.topic.id, ip: "192.168.0.100")
      BadgeGranter.backfill(popular_link_badge)
      expect(UserBadge.where(user_id: post.user.id, badge_id: Badge::PopularLink).count).to eq(0)

      TopicLinkClick.create_from(url: "https://www.discourse.org/", post_id: post.id, topic_id: post.topic.id, ip: "192.168.0.101")
      BadgeGranter.backfill(popular_link_badge)
      expect(UserBadge.where(user_id: post.user.id, badge_id: Badge::PopularLink).count).to eq(1)
    end

    it "is not awarded for links in a restricted category" do
      category = Fabricate(:category)
      post = create_post(raw: "https://www.discourse.org/", category: category)

      category.set_permissions({})
      category.save!

      TopicLinkClick.create_from(url: "https://www.discourse.org/", post_id: post.id, topic_id: post.topic.id, ip: "192.168.0.100")
      TopicLinkClick.create_from(url: "https://www.discourse.org/", post_id: post.id, topic_id: post.topic.id, ip: "192.168.0.101")
      BadgeGranter.backfill(popular_link_badge)
      expect(UserBadge.where(user_id: post.user.id, badge_id: Badge::PopularLink).count).to eq(0)
    end
  end
end
