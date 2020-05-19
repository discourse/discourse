# frozen_string_literal: true
require 'rails_helper'

describe "Topic Thumbnails" do
  before { SiteSetting.create_thumbnails = true }

  fab!(:image) { Fabricate(:image_upload, width: 5000, height: 5000) }
  fab!(:topic) { Fabricate(:topic, image_upload_id: image.id) }
  fab!(:user) { Fabricate(:user) }

  context 'latest' do
    def get_topic
      Discourse.redis.del(topic.thumbnail_job_redis_key(Topic.thumbnail_sizes))
      get '/latest.json'
      response.parsed_body["topic_list"]["topics"][0]
    end

    it "includes thumbnails" do
      topic_json = nil
      expect do
        topic_json = get_topic
      end.to change { Jobs::GenerateTopicThumbnails.jobs.size }.by(1)

      thumbnails = topic_json["thumbnails"]

      # Original only. Optimized not yet generated
      expect(thumbnails.length).to eq(1)

      # Original
      expect(thumbnails[0]["max_width"]).to eq(nil)
      expect(thumbnails[0]["max_height"]).to eq(nil)
      expect(thumbnails[0]["width"]).to eq(image.width)
      expect(thumbnails[0]["height"]).to eq(image.height)
      expect(thumbnails[0]["url"]).to end_with(image.url)

      # Run the job
      args = Jobs::GenerateTopicThumbnails.jobs.last["args"].first
      Jobs::GenerateTopicThumbnails.new.execute(args.with_indifferent_access)

      # Re-request
      expect do
        topic_json = get_topic
      end.to change { Jobs::GenerateTopicThumbnails.jobs.size }.by(0)
      thumbnails = topic_json["thumbnails"]

      expect(thumbnails[1]["max_width"]).to eq(Topic.share_thumbnail_size[0])
      expect(thumbnails[1]["max_height"]).to eq(Topic.share_thumbnail_size[1])
      expect(thumbnails[1]["width"]).to eq(1024)
      expect(thumbnails[1]["height"]).to eq(1024)
      expect(thumbnails[1]["url"]).to include("/optimized/")
    end

    context "with a theme" do
      before do
        theme = Fabricate(:theme)
        theme.theme_modifier_set.topic_thumbnail_sizes = [
          [100, 100],
          [200, 200],
          [300, 300]
        ]
        theme.theme_modifier_set.save!
        theme.set_default!
      end

      it "includes the theme specified resolutions" do
        topic_json = nil

        expect do
          topic_json = get_topic
        end.to change { Jobs::GenerateTopicThumbnails.jobs.size }.by(1)

        # Run the job
        args = Jobs::GenerateTopicThumbnails.jobs.last["args"].first
        Jobs::GenerateTopicThumbnails.new.execute(args.with_indifferent_access)

        # Request again
        expect do
          topic_json = get_topic
        end.to change { Jobs::GenerateTopicThumbnails.jobs.size }.by(0)

        thumbnails = topic_json["thumbnails"]

        # Original + Optimized + 3 theme requests
        expect(thumbnails.length).to eq(5)
      end
    end

    context "with a plugin" do
      before do
        plugin = Plugin::Instance.new
        plugin.register_topic_thumbnail_size [512, 512]
      end

      after do
        DiscoursePluginRegistry.reset!
      end

      it "includes the theme specified resolutions" do
        topic_json = nil

        expect do
          topic_json = get_topic
        end.to change { Jobs::GenerateTopicThumbnails.jobs.size }.by(1)

        # Run the job
        args = Jobs::GenerateTopicThumbnails.jobs.last["args"].first
        Jobs::GenerateTopicThumbnails.new.execute(args.with_indifferent_access)

        # Request again
        expect do
          topic_json = get_topic
        end.to change { Jobs::GenerateTopicThumbnails.jobs.size }.by(0)

        thumbnails = topic_json["thumbnails"]

        # Original + Optimized + 1 plugin request
        expect(thumbnails.length).to eq(3)
      end
    end
  end
end
