# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::DraftReference do
  fab!(:admin)

  let(:draft_class) do
    Class.new(described_class) do
      def self.draft_kind
        "spec"
      end
      private_class_method :draft_kind
    end
  end

  it "round-trips a short user-bound and site-bound payload" do
    reference = draft_class.sign({ value: "safe" }, user: admin)

    expect(reference).to match(/\Aspec_draft_[0-9a-f]{32}\z/)
    expect(draft_class.read(reference)).to include(value: "safe", user_id: admin.id)

    Discourse.stubs(:current_hostname).returns("another.example.com")
    expect(draft_class.read(reference)).to be_nil
  end

  it "rejects malformed, forged, expired, and oversized drafts" do
    reference = draft_class.sign({ value: "safe" }, user: admin)
    expect(draft_class.read("#{reference}tampered")).to be_nil

    forged = draft_class.sign({ value: "forged" }, user: admin)
    Discourse.redis.set(
      "admin-assistant:draft:spec:#{forged}",
      { value: "forged", user_id: admin.id, site: Discourse.current_hostname }.to_json,
    )
    expect(draft_class.read(forged)).to be_nil

    freeze_time 2.days.from_now
    expect(draft_class.read(reference)).to be_nil

    freeze_time 2.days.ago
    expect { draft_class.sign({ value: "x" * 65.kilobytes }, user: admin) }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "releases a claim when a surrounding transaction rolls back" do
    reference = draft_class.sign({ value: "safe" }, user: admin)

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.transaction(requires_new: true) do
        expect(draft_class.claim(reference, reviewable_id: 1)).to eq(true)
        draft_class.complete_after_transaction(reference, reviewable_id: 1, resource_id: 2)
      end
      raise ActiveRecord::Rollback
    end

    expect(draft_class.claim(reference, reviewable_id: 2)).to eq(true)
    draft_class.release(reference, reviewable_id: 2)
  end

  it "blocks concurrent claims and replay after completion" do
    reference = draft_class.sign({ value: "safe" }, user: admin)
    expect(draft_class.claim(reference, reviewable_id: 1)).to eq(true)
    expect(draft_class.claim(reference, reviewable_id: 2)).to eq(false)

    draft_class.complete_after_transaction(reference, reviewable_id: 1, resource_id: 3)
    expect(draft_class.claim(reference, reviewable_id: 4)).to eq(false)
  end
end
