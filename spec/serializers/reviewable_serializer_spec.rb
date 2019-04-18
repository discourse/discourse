require 'rails_helper'

describe ReviewableSerializer do

  let(:reviewable) { Fabricate(:reviewable_queued_post) }
  let(:admin) { Fabricate(:admin) }

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
end
