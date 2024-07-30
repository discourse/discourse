# frozen_string_literal: true

describe Jobs::CleanUpTags do
  subject(:job) { described_class.new }

  let!(:tags) do
    [
      Fabricate(
        :tag,
        name: "used_publically",
        staff_topic_count: 2,
        public_topic_count: 2,
        pm_topic_count: 0,
        created_at: 10.minutes.ago,
      ),
      Fabricate(
        :tag,
        name: "used_privately",
        staff_topic_count: 0,
        public_topic_count: 0,
        pm_topic_count: 3,
        created_at: 10.minutes.ago,
      ),
      Fabricate(
        :tag,
        name: "used_by_staff",
        staff_topic_count: 3,
        public_topic_count: 0,
        pm_topic_count: 0,
        created_at: 10.minutes.ago,
      ),
    ]
  end
  fab!(:unused_tag) do
    Fabricate(
      :tag,
      name: "unused1",
      staff_topic_count: 0,
      public_topic_count: 0,
      pm_topic_count: 0,
      created_at: 10.minutes.ago,
    )
  end
  fab!(:unused_tag_2) do
    Fabricate(
      :tag,
      name: "unused2",
      staff_topic_count: 0,
      public_topic_count: 0,
      pm_topic_count: 0,
      created_at: 10.minutes.ago,
    )
  end

  fab!(:tag_in_group) do
    Fabricate(
      :tag,
      name: "unused_in_group",
      public_topic_count: 0,
      staff_topic_count: 0,
      pm_topic_count: 0,
    )
  end
  fab!(:tag_group) { Fabricate(:tag_group, tag_names: [tag_in_group.name]) }

  it "deletes unused tags" do
    SiteSetting.automatically_clean_unused_tags = true
    expect { job.execute({}) }.to change { Tag.count }.by(-2)
    expect { unused_tag.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect { unused_tag_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "logs action" do
    SiteSetting.automatically_clean_unused_tags = true
    expect { job.execute({}) }.to change { UserHistory.count }.by(1)
    log = UserHistory.last
    expect(log.acting_user_id).to eq(-1)
    expect(log.details).to eq('tags: ["unused1", "unused2"]')
  end

  it "does nothing when site setting is disabled by default" do
    expect { job.execute({}) }.not_to change { Tag.count }
  end
end
