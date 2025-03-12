# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20250304074934_backfill_api_key_scope_modes.rb")

RSpec.describe BackfillApiKeyScopeModes do
  describe "#up" do
    fab!(:global_api_key)
    fab!(:read_only_api_key)
    fab!(:granular_api_key)

    it "backfills with the correct scope modes" do
      silence_stdout do
        expect { described_class.new.up }.to change { read_only_api_key.reload.scope_mode }.from(
          nil,
        ).to("read_only").and change { global_api_key.reload.scope_mode }.from(nil).to(
                "global",
              ).and change { granular_api_key.reload.scope_mode }.from(nil).to("granular")
      end
    end
  end
end
