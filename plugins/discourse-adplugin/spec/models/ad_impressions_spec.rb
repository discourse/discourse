# frozen_string_literal: true

describe AdPlugin::AdImpression do
  fab!(:house_ad)
  fab!(:user)
  fab!(:house_ad_impression) { Fabricate(:house_ad_impression, house_ad: house_ad, user: user) }
  fab!(:external_ad_impression)
  fab!(:anonymous_house_ad_impression)

  before { enable_current_plugin }

  describe "validations" do
    it "is valid with all required attributes for house ad" do
      impression =
        AdPlugin::AdImpression.new(
          ad_type: AdPlugin::AdType[:house],
          placement: "topic_list_top",
          house_ad: house_ad,
        )
      expect(impression).to be_valid
    end

    it "is valid with all required attributes for external ad" do
      impression =
        AdPlugin::AdImpression.new(ad_type: AdPlugin::AdType[:amazon], placement: "topic_list_top")
      expect(impression).to be_valid
    end

    it "requires ad_type" do
      impression = AdPlugin::AdImpression.new(placement: "topic_list_top", house_ad: house_ad)
      expect(impression).not_to be_valid
      expect(impression.errors[:ad_type]).to be_present
    end

    it "requires placement" do
      impression = AdPlugin::AdImpression.new(ad_type: AdPlugin::AdType[:house], house_ad: house_ad)
      expect(impression).not_to be_valid
      expect(impression.errors[:placement]).to be_present
    end

    it "requires house ad id when ad_type is house" do
      impression =
        AdPlugin::AdImpression.new(ad_type: AdPlugin::AdType[:house], placement: "topic_list_top")
      expect(impression).not_to be_valid
      expect(impression.errors[:ad_plugin_house_ad_id]).to be_present
    end

    it "does not require house ad id when ad_type is external" do
      impression =
        AdPlugin::AdImpression.new(ad_type: AdPlugin::AdType[:adsense], placement: "topic_list_top")
      expect(impression).to be_valid
    end

    it "rejects house ad id when ad_type is external" do
      impression =
        AdPlugin::AdImpression.new(
          ad_type: AdPlugin::AdType[:amazon],
          placement: "topic_list_top",
          house_ad: house_ad,
        )
      expect(impression).not_to be_valid
      expect(impression.errors[:ad_plugin_house_ad_id]).to be_present
    end
  end

  describe "associations" do
    it "belongs to house_ad" do
      expect(house_ad_impression.house_ad).to be_present
      expect(house_ad_impression.house_ad).to be_a(AdPlugin::HouseAd)
    end

    it "belongs to user" do
      expect(house_ad_impression.user).to eq(user)
    end

    it "allows nil user (anonymous impressions)" do
      expect(anonymous_house_ad_impression.user).to be_nil
      expect(anonymous_house_ad_impression).to be_valid
    end

    it "allows nil house_ad for external ads" do
      expect(external_ad_impression.house_ad).to be_nil
      expect(external_ad_impression).to be_valid
    end
  end

  describe "enum ad_type" do
    it "defines house ad type" do
      impression = Fabricate(:house_ad_impression)
      expect(house_ad_impression.house?).to eq(true)
      expect(house_ad_impression.adsense?).to eq(false)
    end

    it "defines adsense ad type" do
      impression =
        AdPlugin::AdImpression.create!(ad_type: AdPlugin::AdType[:adsense], placement: "test")
      expect(impression.adsense?).to eq(true)
      expect(impression.house?).to eq(false)
    end

    it "defines dfp ad type" do
      impression =
        AdPlugin::AdImpression.create!(ad_type: AdPlugin::AdType[:dfp], placement: "test")
      expect(impression.dfp?).to eq(true)
      expect(impression.house?).to eq(false)
    end

    it "defines amazon ad type" do
      impression =
        AdPlugin::AdImpression.create!(ad_type: AdPlugin::AdType[:amazon], placement: "test")
      expect(impression.amazon?).to eq(true)
      expect(impression.house?).to eq(false)
    end

    it "defines carbon ad type" do
      impression =
        AdPlugin::AdImpression.create!(ad_type: AdPlugin::AdType[:carbon], placement: "test")
      expect(impression.carbon?).to eq(true)
      expect(impression.house?).to eq(false)
    end

    it "defines adbutler ad type" do
      impression =
        AdPlugin::AdImpression.create!(ad_type: AdPlugin::AdType[:adbutler], placement: "test")
      expect(impression.adbutler?).to eq(true)
      expect(impression.house?).to eq(false)
    end

    it "provides scopes for each ad type" do
      expect(AdPlugin::AdImpression.house).to include(house_ad_impression)
      expect(AdPlugin::AdImpression.house).not_to include(external_ad_impression)

      expect(AdPlugin::AdImpression.amazon).to include(external_ad_impression)
      expect(AdPlugin::AdImpression.amazon).not_to include(house_ad_impression)
    end

    it "allows setting ad_type using bang method" do
      impression = Fabricate(:external_ad_impression)
      impression.adsense!
      expect(impression.adsense?).to eq(true)
      expect(impression.amazon?).to eq(false)
    end
  end

  describe "creating impressions" do
    it "creates house ad impression" do
      expect(house_ad_impression).to be_persisted
      expect(AdPlugin::AdType.types[house_ad_impression.ad_type.to_sym]).to eq(
        AdPlugin::AdType[:house],
      )
      expect(house_ad_impression.house_ad).to eq(house_ad)
    end

    it "creates external ad impression" do
      expect(external_ad_impression).to be_persisted
      expect(AdPlugin::AdType.types[external_ad_impression.ad_type.to_sym]).to eq(
        AdPlugin::AdType[:amazon],
      )
      expect(external_ad_impression.house_ad).to be_nil
    end

    it "creates impression with user" do
      expect(house_ad_impression.user).to eq(user)
    end

    it "creates impression without user (anonymous)" do
      house_ad_impression.user = nil
      house_ad_impression.save
      re_loaded_house_ad_impression = AdPlugin::AdImpression.find(house_ad_impression.id)
      expect(house_ad_impression.user).to be_nil
    end

    it "records placement" do
      expect(house_ad_impression.placement).to eq("topic_list_top")
    end

    it "records timestamps" do
      expect(house_ad_impression.created_at).to be_present
      expect(house_ad_impression.updated_at).to be_present
    end
  end

  describe "querying impressions" do
    fab!(:house_impression1) { Fabricate(:house_ad_impression, house_ad: house_ad, user: user) }
    fab!(:house_impression2) { Fabricate(:house_ad_impression, house_ad: house_ad, user: nil) }
    fab!(:external_impression) { Fabricate(:external_ad_impression, user: user) }

    it "finds all impressions" do
      expect(AdPlugin::AdImpression.all).to include(
        house_impression1,
        house_impression2,
        external_impression,
      )
    end

    it "filters by ad_type" do
      house_impressions = AdPlugin::AdImpression.house
      expect(house_impressions).to include(house_impression1, house_impression2)
      expect(house_impressions).not_to include(external_impression)
    end

    it "filters by user" do
      user_impressions = AdPlugin::AdImpression.where(user: user)
      expect(user_impressions).to include(house_impression1, external_impression)
      expect(user_impressions).not_to include(house_impression2)
    end

    it "filters by house_ad" do
      house_ad_impressions = AdPlugin::AdImpression.where(house_ad: house_ad)
      expect(house_ad_impressions).to include(house_impression1, house_impression2)
      expect(house_ad_impressions).not_to include(external_impression)
    end

    it "filters by placement" do
      placement = house_impression1.placement
      placement_impressions = AdPlugin::AdImpression.where(placement: placement)
      expect(placement_impressions.count).to be >= 1
    end
  end

  describe "cascade deletion" do
    fab!(:impression) { Fabricate(:house_ad_impression, house_ad: house_ad, user: user) }
    it "deletes impressions when house_ad is deleted" do
      impression_id = impression.id

      house_ad.destroy!

      expect { AdPlugin::AdImpression.find(impression_id) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "nullifies user_id when user is deleted" do
      user_id = user.id

      user.destroy!
      impression.reload

      expect(impression.user_id).to be_nil
      expect(impression).to be_persisted
    end
  end

  describe "#record_click!" do
    fab!(:impression, :house_ad_impression)

    it "records the click timestamp" do
      freeze_time

      expect(impression.clicked_at).to be_nil
      expect(impression.record_click!).to eq(true)

      impression.reload
      expect(impression.clicked_at).to be_within(1.second).of(Time.zone.now)
    end

    it "prevents duplicate clicks" do
      impression.record_click!
      original_time = impression.clicked_at

      expect(impression.record_click!).to eq(false)
      impression.reload
      expect(impression.clicked_at).to eq_time(original_time)
    end
  end

  describe "#clicked?" do
    fab!(:impression, :house_ad_impression)

    it "returns false when not clicked" do
      expect(impression.clicked?).to eq(false)
    end

    it "returns true when clicked" do
      impression.record_click!
      expect(impression.clicked?).to eq(true)
    end
  end
end
