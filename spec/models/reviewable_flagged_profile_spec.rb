# frozen_string_literal: true

RSpec.describe ReviewableFlaggedProfile do
  fab!(:owner, :user)
  fab!(:reporter, :user)
  fab!(:moderator)
  fab!(:reviewable) do
    Fabricate(:reviewable_flagged_profile, target: owner.user_profile, created_by: reporter)
  end

  describe "#perform" do
    it "removes current public content and keeps the reported snapshot" do
      enable_dsa_reporting
      profile = owner.user_profile
      reported_avatar = Fabricate(:upload)
      current_avatar = Fabricate(:upload)
      reported_header = Fabricate(:upload)
      current_header = Fabricate(:upload)
      reported_card = Fabricate(:upload)
      current_card = Fabricate(:upload)
      public_field = Fabricate(:user_field, show_on_profile: true)
      private_field = Fabricate(:user_field, show_on_profile: false)
      profile.update!(
        bio_raw: "Reported bio",
        location: "Sydney",
        website: "https://example.com",
        profile_background_upload: reported_header,
        card_background_upload: reported_card,
      )
      owner.update!(name: "Profile owner", title: "Contributor")
      owner.pick_avatar!(reported_avatar.id, type: :uploaded)
      owner.set_user_field(public_field.id, "Reported value")
      owner.save_custom_fields
      reviewable.capture_profile!(profile)
      snapshot = reviewable.reload.payload.deep_dup
      expect(snapshot["card_background_url"]).to eq(Discourse.store.cdn_url(reported_card.url))

      profile.update!(
        bio_raw: "Bio edited after the report",
        website: "https://updated.example.com",
        profile_background_upload: current_header,
        card_background_upload: current_card,
      )
      owner.pick_avatar!(current_avatar.id, type: :uploaded)
      new_field = Fabricate(:user_field, show_on_profile: true)
      owner.set_user_field(public_field.id, "Edited after reporting")
      owner.set_user_field(new_field.id, "Added after reporting")
      owner.set_user_field(private_field.id, "Private value")
      owner.custom_fields["plugin_preference"] = "kept"
      owner.save_custom_fields
      Fabricate(:watched_word, word: profile.location.downcase)

      reviewable.perform(moderator, :remove_profile_content)

      expect(profile.reload).to have_attributes(
        bio_raw: nil,
        bio_cooked: nil,
        location: "Sydney",
        website: nil,
        profile_background_upload_id: nil,
        card_background_upload_id: nil,
      )
      expect(profile.upload_references).to be_empty
      expect(owner.reload).to have_attributes(
        uploaded_avatar_id: nil,
        name: "Profile owner",
        title: "Contributor",
      )
      expect(owner.user_avatar.custom_upload_id).to be_nil
      expect(owner.user_fields).to include(
        public_field.id.to_s => nil,
        new_field.id.to_s => nil,
        private_field.id.to_s => "Private value",
      )
      expect(owner.custom_fields["plugin_preference"]).to eq("kept")
      expect(reviewable.reload).to be_approved
      expect(reviewable.payload).to eq(snapshot)
      expect(reviewable.upload_references.pluck(:upload_id)).to contain_exactly(
        reported_avatar.id,
        reported_header.id,
        reported_card.id,
      )
      expect(reviewable.reviewable_notes.sole.user).to eq(moderator)
      expect(reporter.user_stat.reload.flags_agreed).to eq(1)
      expect(reviewable.dsa_statement_of_records.sole.payload).to include(
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        "content_type" => %w[CONTENT_TYPE_TEXT CONTENT_TYPE_IMAGE],
      )
    end

    it "dates an avatar-only restriction using the removed upload" do
      enable_dsa_reporting
      avatar = Fabricate(:upload, created_at: 3.days.ago)
      owner.pick_avatar!(avatar.id, type: :uploaded)

      reviewable.perform(moderator, :remove_profile_content)

      expect(reviewable.dsa_statement_of_records.sole.payload).to include(
        "content_type" => ["CONTENT_TYPE_IMAGE"],
        "content_date" => avatar.created_at.to_date.iso8601,
      )
    end

    it "dates a user-card-only restriction using the removed background" do
      enable_dsa_reporting
      card = Fabricate(:upload, created_at: 3.days.ago)
      owner.user_profile.update!(card_background_upload: card)

      reviewable.perform(moderator, :remove_profile_content)

      expect(owner.user_profile.reload.card_background_upload_id).to be_nil
      expect(reviewable.dsa_statement_of_records.sole.payload).to include(
        "content_type" => ["CONTENT_TYPE_IMAGE"],
        "content_date" => card.created_at.to_date.iso8601,
      )
    end

    it "records both a website and a profile header removed from an otherwise empty profile" do
      enable_dsa_reporting
      owner.update_column(:created_at, 1.year.ago)
      header = Fabricate(:upload, created_at: 3.days.ago)
      owner.user_profile.update!(website: "https://example.com", profile_background_upload: header)

      reviewable.perform(moderator, :remove_profile_content)

      expect(reviewable.dsa_statement_of_records.sole.payload).to include(
        "content_type" => contain_exactly("CONTENT_TYPE_IMAGE", "CONTENT_TYPE_TEXT"),
        "content_date" => header.created_at.to_date.iso8601,
      )
    end

    it "removes searchable public field values from search even when they are the only profile content" do
      enable_dsa_reporting
      owner.update_column(:created_at, 1.year.ago)
      field = Fabricate(:user_field, show_on_profile: true, searchable: true)
      field_value = "searchablebiography"
      owner.set_user_field(field.id, field_value)
      SearchIndexer.with_indexing do
        owner.save!
        expect(owner.user_search_data.raw_data).to include(field_value)
        field_date =
          owner.user_custom_fields.find_by!(name: "user_field_#{field.id}").updated_at.to_date

        reviewable.perform(moderator, :remove_profile_content)

        expect(owner.user_search_data.reload.raw_data).not_to include(field_value)
        expect(reviewable.dsa_statement_of_records.sole.payload).to include(
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => field_date.iso8601,
        )
      end
    end

    it "can confirm a report whose content is already gone without recording a DSA restriction" do
      enable_dsa_reporting
      owner.user_profile.update!(bio_raw: "Reported bio")
      reviewable.capture_profile!(owner.user_profile)
      owner.user_profile.update!(bio_raw: nil)

      reviewable.perform(moderator, :remove_profile_content)

      expect(reviewable.reload).to be_approved
      expect(reviewable.dsa_statement_of_records).to be_empty
      expect(reviewable.reviewable_notes).to be_empty
    end

    it "clears blank or hidden field values without recording a public content restriction" do
      enable_dsa_reporting
      empty_text = Fabricate(:user_field, show_on_profile: true)
      unchecked = Fabricate(:user_field, field_type: "confirm", show_on_profile: true)
      owner.set_user_field(empty_text.id, "")
      owner.set_user_field(unchecked.id, false)
      owner.save_custom_fields

      reviewable.perform(moderator, :remove_profile_content)

      expect(owner.reload.user_custom_fields).to be_empty
      expect(reviewable.dsa_statement_of_records).to be_empty
      expect(reviewable.reviewable_notes).to be_empty
    end

    it "uses the date of the visible value when a newer public field is blank" do
      enable_dsa_reporting
      number = Fabricate(:user_field, field_type: "number", show_on_profile: true)
      empty_text = Fabricate(:user_field, show_on_profile: true)
      date = 3.days.ago
      freeze_time(date) do
        owner.set_user_field(number.id, "0")
        owner.save_custom_fields
      end
      owner.set_user_field(empty_text.id, "")
      owner.save_custom_fields

      reviewable.perform(moderator, :remove_profile_content)

      expect(reviewable.dsa_statement_of_records.sole.payload).to include(
        "content_type" => ["CONTENT_TYPE_TEXT"],
        "content_date" => date.to_date.iso8601,
      )
    end

    it "confirms the report once a suspension succeeds and records the account restriction" do
      enable_dsa_reporting
      expect(reviewable.perform(moderator, :suspend_user, reason: "Spam")).not_to be_success
      expect(reviewable.reload).to be_pending
      expect(owner.reload).not_to be_suspended
      expect(reviewable.dsa_statement_of_records).to be_empty

      expiry = 2.days.from_now.change(usec: 0)
      reviewable.perform(moderator, :suspend_user, reason: "Spam", suspend_until: expiry)
      expect(reviewable.reload).to be_approved
      expect(owner.reload.suspended_till).to eq(expiry)
      expect(reporter.user_stat.reload.flags_agreed).to eq(1)
      expect(reviewable.dsa_statement_of_records.sole.payload).to include(
        "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
        "end_date_account_restriction" => expiry.to_date.iso8601,
      )
    end

    it "counts ignored flags for reporters other than the profile owner" do
      reviewable.add_score(owner, ReviewableScore.types[:spam], force_review: true)

      reviewable.perform(moderator, :ignore)

      expect(reviewable.reload).to be_ignored
      expect(reviewable.reviewable_scores).to all(be_ignored)
      expect(reporter.user_stat.reload.flags_ignored).to eq(1)
      expect(owner.user_stat.reload.flags_ignored).to eq(0)
    end

    it "withholds account penalties when the moderator cannot apply them to the profile owner" do
      owner.update!(moderator: true)
      actions = reviewable.actions_for(moderator.guardian)
      expect(actions.to_a.map(&:server_action)).to contain_exactly(
        "agree_profile_flag",
        "dismiss_profile_flag",
        "ignore",
      )
      expect(actions.bundles.first.actions.sole.label).to eq(actions.bundles.first.label)
      expect { reviewable.perform(moderator, :silence_user) }.to raise_error(
        Reviewable::InvalidAction,
      )
      expect { reviewable.perform(moderator, :remove_profile_content) }.to raise_error(
        Reviewable::InvalidAction,
      )
      expect { reviewable.perform(reporter, :remove_profile_content) }.to raise_error(
        Reviewable::InvalidAction,
      )
      expect(reviewable.reload).to be_pending
    end
  end
end
