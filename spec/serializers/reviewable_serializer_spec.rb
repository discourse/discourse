# frozen_string_literal: true

require 'rails_helper'

describe ReviewableSerializer do

  fab!(:reviewable) { Fabricate(:reviewable_queued_post) }
  fab!(:admin) { Fabricate(:admin) }

  it "serializes all the fields" do
    json = described_class.new(reviewable, scope: Guardian.new(admin), root: nil).as_json

    expect(json[:id]).to eq(reviewable.id)
    expect(json[:status]).to eq(reviewable.status)
    expect(json[:type]).to eq(reviewable.type)
    expect(json[:created_at]).to eq(reviewable.created_at)
    expect(json[:category_id]).to eq(reviewable.category_id)
    expect(json[:can_edit]).to eq(true)
    expect(json[:version]).to eq(0)
    expect(json[:removed_topic_id]).to be_nil
  end

  it 'Includes the removed topic id when the topis was deleted' do
    reviewable.topic.trash!(admin)
    json = described_class.new(reviewable.reload, scope: Guardian.new(admin), root: nil).as_json
    expect(json[:removed_topic_id]).to eq reviewable.topic_id
  end

  it "will not throw an error when the payload is `nil`" do
    reviewable.payload = nil
    json = ReviewableQueuedPostSerializer.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
    expect(json['payload']).to be_blank
  end

  describe "urls" do

    it "links to the flagged post" do
      fp = Fabricate(:reviewable_flagged_post)
      json = described_class.new(fp, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:target_url]).to eq(Discourse.base_url + fp.post.url)
      expect(json[:topic_url]).to eq(fp.topic.url)
    end

    it "supports deleted topics" do
      fp = Fabricate(:reviewable_flagged_post)
      fp.topic.trash!(admin)
      fp.reload

      json = described_class.new(fp, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:topic_url]).to be_blank
    end

    it "links to the queued post" do
      json = described_class.new(reviewable, scope: Guardian.new(admin), root: nil).as_json
      expect(json[:target_url]).to eq(reviewable.topic.url)
      expect(json[:topic_url]).to eq(reviewable.topic.url)
    end
  end
end
