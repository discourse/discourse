# frozen_string_literal: true

require 'rails_helper'

describe About do

  describe 'stats cache' do
    include_examples 'stats cachable'
  end

  describe "#category_moderators" do
    let(:user) { Fabricate(:user) }
    let(:public_cat_moderator) { Fabricate(:user, last_seen_at: 1.month.ago) }
    let(:private_cat_moderator) { Fabricate(:user, last_seen_at: 2.month.ago) }
    let(:common_moderator) { Fabricate(:user, last_seen_at: 3.month.ago) }
    let(:common_moderator_2) { Fabricate(:user, last_seen_at: 4.month.ago) }

    let(:public_group) do
      group = Fabricate(:public_group)
      group.add(public_cat_moderator)
      group.add(common_moderator)
      group.add(common_moderator_2)
      group
    end

    let(:private_group) do
      group = Fabricate(:group)
      group.add(private_cat_moderator)
      group.add(common_moderator)
      group.add(common_moderator_2)
      group
    end

    let!(:public_cat) { Fabricate(:category, reviewable_by_group: public_group) }
    let!(:private_cat) { Fabricate(:private_category, group: private_group, reviewable_by_group: private_group) }

    it "lists moderators of the category that the current user can see" do
      results = About.new(private_cat_moderator).category_moderators
      expect(results.map(&:category_id)).to contain_exactly(public_cat.id, private_cat.id)
      expect(results.map(&:moderators).flatten.map(&:id).uniq).to contain_exactly(
        public_cat_moderator.id,
        common_moderator.id,
        common_moderator_2.id,
        private_cat_moderator.id
      )

      [public_cat_moderator, user, nil].each do |u|
        results = About.new(u).category_moderators
        expect(results.map(&:category_id)).to contain_exactly(public_cat.id)
        expect(results.map(&:moderators).flatten.map(&:id)).to eq([
          public_cat_moderator.id,
          common_moderator.id,
          common_moderator_2.id
        ])
      end
    end

    it "limit category moderators when there are too many for perf reasons" do
      about = About.new(private_cat_moderator)
      about.category_mods_limit = 4
      results = about.category_moderators
      expect(results.size).to eq(2)
      results.each do |res|
        expect(res.moderators.size).to eq(2)
      end
    end
  end
end
