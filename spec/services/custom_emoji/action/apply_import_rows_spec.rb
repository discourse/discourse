# frozen_string_literal: true

RSpec.describe CustomEmoji::Action::ApplyImportRows do
  describe "#call" do
    subject(:report) { described_class.call(rows:, resolutions:, acting_user:) }

    fab!(:acting_user, :admin)
    fab!(:staged_upload, :upload)

    let(:resolutions) { {} }

    def build_row(name:, category:, index: 0, group: nil, upload_id: staged_upload.id)
      CustomEmoji::ImportRow.new(
        index:,
        name:,
        group:,
        filename: "#{name}.png",
        category:,
        upload_id:,
      )
    end

    context "with an invalid row" do
      let(:rows) { [build_row(name: "broken", category: CustomEmoji::ImportRow::CATEGORY_INVALID)] }

      it "skips it without creating anything or counting it" do
        expect { report }.not_to change { CustomEmoji.count }
        expect(report).to eq(created: 0, updated: 0, skipped: 0)
      end
    end

    context "with an identical row" do
      let(:rows) do
        [build_row(name: "same-emoji", category: CustomEmoji::ImportRow::CATEGORY_IDENTICAL)]
      end

      it "counts it as skipped without creating anything" do
        expect { report }.not_to change { CustomEmoji.count }
        expect(report).to eq(created: 0, updated: 0, skipped: 1)
      end
    end

    context "with a conflict row resolved with keep" do
      fab!(:existing_emoji) { Fabricate(:custom_emoji, name: "keep-me", group: "old") }

      let(:resolutions) { { "keep-me" => "keep" } }
      let(:rows) do
        [
          build_row(
            name: "keep-me",
            group: "new-group",
            category: CustomEmoji::ImportRow::CATEGORY_CONFLICT_GROUP,
          ),
        ]
      end

      it "leaves the existing emoji untouched and counts nothing" do
        expect { report }.not_to change { existing_emoji.reload.attributes }
        expect(report).to eq(created: 0, updated: 0, skipped: 0)
      end

      context "when the resolution keys were symbolized" do
        let(:resolutions) { { "keep-me": "keep" } }

        it "still keeps the existing emoji" do
          expect { report }.not_to change { existing_emoji.reload.attributes }
        end
      end
    end

    context "with a row whose staged upload no longer exists" do
      let(:rows) do
        [build_row(name: "gone", category: CustomEmoji::ImportRow::CATEGORY_NEW, upload_id: 0)]
      end

      it "skips it without creating anything or counting it" do
        expect { report }.not_to change { CustomEmoji.count }
        expect(report).to eq(created: 0, updated: 0, skipped: 0)
      end
    end

    context "with a conflict row for an existing emoji" do
      fab!(:existing_emoji) { Fabricate(:custom_emoji, name: "clash", group: "old") }

      let(:rows) do
        [
          build_row(
            name: "clash",
            group: "fresh",
            category: CustomEmoji::ImportRow::CATEGORY_CONFLICT_BOTH,
          ),
        ]
      end

      it "updates the emoji with the incoming upload and group" do
        expect { report }.to change { existing_emoji.reload.upload_id }.to(staged_upload.id).and(
          change { existing_emoji.reload.group }.from("old").to("fresh"),
        )
        expect(report).to eq(created: 0, updated: 1, skipped: 0)
      end

      it "logs the change" do
        expect { report }.to change {
          UserHistory.where(action: UserHistory.actions[:custom_emoji_create]).count
        }.by(1)
      end
    end

    context "with a new row" do
      let(:rows) do
        [build_row(name: "brand-new", group: "fun", category: CustomEmoji::ImportRow::CATEGORY_NEW)]
      end

      it "creates the emoji for the acting user" do
        expect { report }.to change { CustomEmoji.count }.by(1)
        expect(CustomEmoji.find_by(name: "brand-new")).to have_attributes(
          group: "fun",
          upload_id: staged_upload.id,
          user_id: acting_user.id,
        )
        expect(report).to eq(created: 1, updated: 0, skipped: 0)
      end

      it "logs the change" do
        expect { report }.to change {
          UserHistory.where(action: UserHistory.actions[:custom_emoji_create]).count
        }.by(1)
      end
    end

    context "with a mix of new, conflicting and identical rows" do
      fab!(:existing_emoji) { Fabricate(:custom_emoji, name: "clash", group: "old") }

      let(:rows) do
        [
          build_row(name: "brand-new", index: 0, category: CustomEmoji::ImportRow::CATEGORY_NEW),
          build_row(
            name: "clash",
            index: 1,
            category: CustomEmoji::ImportRow::CATEGORY_CONFLICT_IMAGE,
          ),
          build_row(
            name: "same-emoji",
            index: 2,
            category: CustomEmoji::ImportRow::CATEGORY_IDENTICAL,
          ),
        ]
      end

      it "reports the totals per outcome" do
        expect(report).to eq(created: 1, updated: 1, skipped: 1)
      end
    end
  end
end
