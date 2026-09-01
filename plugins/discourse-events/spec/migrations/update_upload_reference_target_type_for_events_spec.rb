# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-events/db/post_migrate/20260819131113_update_upload_reference_target_type_for_events.rb",
        )

RSpec.describe UpdateUploadReferenceTargetTypeForEvents do
  subject(:migrate) { described_class.new.up }

  fab!(:upload)
  fab!(:other_upload, :upload)
  fab!(:event) { Fabricate(:event, post: Fabricate(:post)) }

  around do |example|
    original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    UploadReference.delete_all
    example.run
  ensure
    ActiveRecord::Migration.verbose = original_verbose
  end

  def reference(upload_id:, target_type:, target_id:)
    UploadReference.insert_all(
      [
        {
          upload_id:,
          target_type:,
          target_id:,
          created_at: Time.zone.now,
          updated_at: Time.zone.now,
        },
      ],
    )
  end

  def target_types_for(upload_id)
    UploadReference.where(upload_id:).pluck(:target_type)
  end

  it "moves references onto the renamed model" do
    reference(upload_id: upload.id, target_type: "DiscoursePostEvent::Event", target_id: event.id)

    migrate

    expect(target_types_for(upload.id)).to eq(["DiscourseEvents::Events::Event"])
  end

  it "leaves references belonging to other models alone" do
    reference(upload_id: upload.id, target_type: "Post", target_id: event.id)

    migrate

    expect(target_types_for(upload.id)).to eq(["Post"])
  end

  it "keeps a stale row that has no renamed counterpart for that upload" do
    reference(upload_id: upload.id, target_type: "DiscoursePostEvent::Event", target_id: event.id)
    reference(
      upload_id: other_upload.id,
      target_type: "DiscourseEvents::Events::Event",
      target_id: event.id,
    )

    migrate

    expect(target_types_for(upload.id)).to eq(["DiscourseEvents::Events::Event"])
    expect(target_types_for(other_upload.id)).to eq(["DiscourseEvents::Events::Event"])
  end

  it "reconnects the association the model reads" do
    reference(upload_id: upload.id, target_type: "DiscoursePostEvent::Event", target_id: event.id)

    expect(event.reload.upload_references).to be_empty

    migrate

    expect(event.reload.upload_references.pluck(:upload_id)).to eq([upload.id])
  end
end
