# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::CleanUpUnusedStagedUsers do
  fab!(:staged_user) { Fabricate(:user, staged: true) }

  shared_examples "does not delete" do
    it "doesn't delete the staged user" do
      expect { described_class.new.execute({}) }.to_not change { User.count }
      expect(User.exists?(staged_user.id)).to eq(true)
    end
  end

  context "when staged user is unused" do
    context "when staged user is old enough" do
      before { staged_user.update!(created_at: 2.years.ago) }

      context "regular staged user" do
        it "deletes the staged user" do
          expect { described_class.new.execute({}) }.to change { User.count }.by(-1)
          expect(User.exists?(staged_user.id)).to eq(false)
        end
      end

      context "staged admin" do
        before { staged_user.update!(admin: true) }
        include_examples "does not delete"
      end

      context "staged moderator" do
        before { staged_user.update!(moderator: true) }
        include_examples "does not delete"
      end
    end

    context 'when staged user is not old enough' do
      before { staged_user.update!(created_at: 5.months.ago) }
      include_examples "does not delete"
    end
  end

  context "when staged user has posts" do
    before { Fabricate(:post, user: staged_user) }
    include_examples "does not delete"
  end

  it "doesn't delete regular, unused user" do
    user = Fabricate(:user, created_at: 2.years.ago)

    expect { described_class.new.execute({}) }.to_not change { User.count }
    expect(User.exists?(user.id)).to eq(true)
  end
end
