# frozen_string_literal: true

RSpec.describe CustomEmoji::ConfirmImport do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:token) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :admin)
    fab!(:staged_upload, :upload)
    fab!(:existing_emoji) { Fabricate(:custom_emoji, name: "conflict-emoji", group: "old") }

    let(:params) { { token:, resolutions: } }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:resolutions) { {} }
    let(:token) { CustomEmoji::ImportPreviewCache.new(current_user).store(rows) }
    let(:rows) do
      [
        CustomEmoji::ImportRow.new(
          index: 0,
          name: "confirm-new",
          group: "fun",
          filename: "confirm-new.png",
          category: CustomEmoji::ImportRow::CATEGORY_NEW,
          upload_id: staged_upload.id,
        ),
        CustomEmoji::ImportRow.new(
          index: 1,
          name: "conflict-emoji",
          group: nil,
          filename: "conflict-emoji.png",
          category: CustomEmoji::ImportRow::CATEGORY_CONFLICT_IMAGE,
          upload_id: staged_upload.id,
        ),
        CustomEmoji::ImportRow.new(
          index: 2,
          name: "same-emoji",
          group: nil,
          filename: "same-emoji.png",
          category: CustomEmoji::ImportRow::CATEGORY_IDENTICAL,
        ),
      ]
    end

    context "when contract is invalid" do
      let(:token) { "" }

      it { is_expected.to fail_a_contract }
    end

    context "when the token is unknown or expired" do
      let(:token) { "unknown-token" }

      it { is_expected.to fail_to_find_a_model(:rows) }
    end

    context "when a row fails to apply" do
      let(:rows) do
        [
          CustomEmoji::ImportRow.new(
            index: 0,
            name: "rollback-ok",
            group: nil,
            filename: "rollback-ok.png",
            category: CustomEmoji::ImportRow::CATEGORY_NEW,
            upload_id: staged_upload.id,
          ),
          CustomEmoji::ImportRow.new(
            index: 1,
            name: "",
            group: nil,
            filename: "bad.png",
            category: CustomEmoji::ImportRow::CATEGORY_NEW,
            upload_id: staged_upload.id,
          ),
        ]
      end

      it { is_expected.to fail_with_exception(ActiveRecord::RecordInvalid) }

      it "rolls back emojis created earlier in the batch" do
        expect { result }.not_to change { CustomEmoji.count }
      end

      it "keeps the staged manifest in Redis" do
        result
        expect(Discourse.redis.exists?("emoji_import_preview:#{current_user.id}:#{token}")).to eq(
          true,
        )
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "reports created, updated and skipped counts" do
        expect(result[:report]).to eq(created: 1, updated: 1, skipped: 1)
      end

      it "creates the new emoji with its group" do
        expect { result }.to change { CustomEmoji.count }.by(1)
        expect(CustomEmoji.find_by(name: "confirm-new")).to have_attributes(
          group: "fun",
          upload_id: staged_upload.id,
          user_id: current_user.id,
        )
      end

      it "updates the conflicting emoji with the incoming upload and group" do
        expect { result }.to change { existing_emoji.reload.upload_id }.to(staged_upload.id).and(
          change { existing_emoji.reload.group }.from("old").to(nil),
        )
      end

      it "logs the applied changes" do
        expect { result }.to change {
          UserHistory.where(action: UserHistory.actions[:custom_emoji_create]).count
        }.by(2)
      end

      it "deletes the staged manifest from Redis" do
        result
        expect(Discourse.redis.exists?("emoji_import_preview:#{current_user.id}:#{token}")).to eq(
          false,
        )
      end
    end

    context "when a conflict is resolved with keep" do
      let(:resolutions) { { "conflict-emoji" => "keep" } }

      it { is_expected.to run_successfully }

      it "leaves the existing emoji untouched" do
        expect { result }.not_to change { existing_emoji.reload.attributes }
      end
    end
  end
end
