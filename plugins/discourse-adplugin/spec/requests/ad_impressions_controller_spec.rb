# frozen_string_literal: true

describe AdPlugin::AdImpressionsController do
  fab!(:user)
  fab!(:house_ad)

  before { enable_current_plugin }

  describe "#create" do
    context "when creating house ad impression" do
      it "creates impression for logged in user" do
        sign_in(user)

        expect {
          post "/ad_plugin/ad_impressions.json",
               params: {
                 ad_plugin_impression: {
                   ad_type: AdPlugin::AdType.types[:house],
                   placement: "topic_list_top",
                   ad_plugin_house_ad_id: house_ad.id,
                 },
               }
        }.to change { AdPlugin::AdImpression.count }.by(1)

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["ad_type"]).to eq(AdPlugin::AdType[AdPlugin::AdType.types[:house]].to_s)
        expect(json["placement"]).to eq("topic_list_top")
        expect(json["user_id"]).to eq(user.id)

        impression = AdPlugin::AdImpression.last
        expect(impression.house?).to eq(true)
        expect(impression.house_ad).to eq(house_ad)
        expect(impression.user).to eq(user)
      end

      it "creates impression for anonymous user" do
        expect {
          post "/ad_plugin/ad_impressions.json",
               params: {
                 ad_plugin_impression: {
                   ad_type: AdPlugin::AdType.types[:house],
                   placement: "topic_list_top",
                   ad_plugin_house_ad_id: house_ad.id,
                 },
               }
        }.to change { AdPlugin::AdImpression.count }.by(1)

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["user_id"]).to be_nil

        impression = AdPlugin::AdImpression.last
        expect(impression.user).to be_nil
      end
    end

    context "when creating external ad impression" do
      it "creates impression for adsense" do
        sign_in(user)

        expect {
          post "/ad_plugin/ad_impressions.json",
               params: {
                 ad_plugin_impression: {
                   ad_type: AdPlugin::AdType.types[:adsense],
                   placement: "topic_above_post_stream",
                 },
               }
        }.to change { AdPlugin::AdImpression.count }.by(1)

        expect(response.status).to eq(200)
        impression = AdPlugin::AdImpression.last
        expect(impression.adsense?).to eq(true)
        expect(impression.house_ad).to be_nil
      end

      it "creates impression for amazon" do
        post "/ad_plugin/ad_impressions.json",
             params: {
               ad_plugin_impression: {
                 ad_type: AdPlugin::AdType.types[:amazon],
                 placement: "post_bottom",
               },
             }

        expect(response.status).to eq(200)
        impression = AdPlugin::AdImpression.last
        expect(impression.amazon?).to eq(true)
      end
    end

    context "when validation fails" do
      it "returns error for missing ad_type" do
        sign_in(user)

        expect {
          post "/ad_plugin/ad_impressions.json",
               params: {
                 ad_plugin_impression: {
                   placement: "topic_list_top",
                 },
               }
        }.not_to change { AdPlugin::AdImpression.count }

        expect(response.status).to eq(422)
      end

      it "returns error for missing placement" do
        sign_in(user)

        expect {
          post "/ad_plugin/ad_impressions.json",
               params: {
                 ad_plugin_impression: {
                   ad_type: AdPlugin::AdType.types[:house],
                   ad_plugin_house_ad_id: house_ad.id,
                 },
               }
        }.not_to change { AdPlugin::AdImpression.count }

        expect(response.status).to eq(422)
      end

      it "returns error when house ad missing house_ad_id" do
        sign_in(user)

        expect {
          post "/ad_plugin/ad_impressions.json",
               params: {
                 ad_plugin_impression: {
                   ad_type: AdPlugin::AdType.types[:house],
                   placement: "topic_list_top",
                 },
               }
        }.not_to change { AdPlugin::AdImpression.count }

        expect(response.status).to eq(422)
      end

      it "returns error when external ad includes house_ad_id" do
        sign_in(user)

        expect {
          post "/ad_plugin/ad_impressions.json",
               params: {
                 ad_plugin_impression: {
                   ad_type: AdPlugin::AdType.types[:adsense],
                   placement: "topic_list_top",
                   ad_plugin_house_ad_id: house_ad.id,
                 },
               }
        }.not_to change { AdPlugin::AdImpression.count }

        expect(response.status).to eq(422)
      end
    end

    context "when recording different placements" do
      it "records topic_list_top placement" do
        post "/ad_plugin/ad_impressions.json",
             params: {
               ad_plugin_impression: {
                 ad_type: AdPlugin::AdType.types[:dfp],
                 placement: "topic_list_top",
               },
             }

        impression = AdPlugin::AdImpression.last
        expect(impression.placement).to eq("topic_list_top")
      end

      it "records topic_above_post_stream placement" do
        post "/ad_plugin/ad_impressions.json",
             params: {
               ad_plugin_impression: {
                 ad_type: AdPlugin::AdType.types[:carbon],
                 placement: "topic_above_post_stream",
               },
             }

        impression = AdPlugin::AdImpression.last
        expect(impression.placement).to eq("topic_above_post_stream")
      end

      it "records post_bottom placement" do
        post "/ad_plugin/ad_impressions.json",
             params: {
               ad_plugin_impression: {
                 ad_type: AdPlugin::AdType.types[:adbutler],
                 placement: "post_bottom",
               },
             }

        impression = AdPlugin::AdImpression.last
        expect(impression.placement).to eq("post_bottom")
      end
    end
  end

  describe "#update" do
    fab!(:impression) { Fabricate(:house_ad_impression, user: user, house_ad: house_ad) }

    it "records a click on an impression" do
      freeze_time

      patch "/ad_plugin/ad_impressions/#{impression.id}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["success"]).to eq(true)
      expect(json["clicked_at"]).to be_present

      impression.reload
      expect(impression.clicked_at).to be_within(1.second).of(Time.zone.now)
      expect(impression.clicked?).to eq(true)
    end

    it "prevents recording duplicate clicks" do
      impression.record_click!

      patch "/ad_plugin/ad_impressions/#{impression.id}.json"

      expect(response.status).to eq(422)
      json = response.parsed_body
      expect(json["success"]).to eq(false)
      expect(json["error"]).to eq("Click already recorded")
    end

    it "works for external ad impressions" do
      external_impression = Fabricate(:external_ad_impression)

      freeze_time

      patch "/ad_plugin/ad_impressions/#{external_impression.id}.json"

      expect(response.status).to eq(200)

      external_impression.reload
      expect(external_impression.clicked_at).to be_within(1.second).of(Time.zone.now)
    end

    it "also accepts POST requests for sendBeacon compatibility" do
      freeze_time

      post "/ad_plugin/ad_impressions/#{impression.id}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["success"]).to eq(true)
      expect(json["clicked_at"]).to be_present

      impression.reload
      expect(impression.clicked_at).to be_within(1.second).of(Time.zone.now)
    end
  end
end
