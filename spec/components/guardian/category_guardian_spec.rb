require 'spec_helper'

describe CategoryGuardian do
  let(:user) { build(:user) }
  let(:moderator) { build(:moderator) }
  let(:admin) { build(:admin) }

  describe 'can_create_category?' do
    it 'returns false when not logged in' do
      Guardian.new.can_create?(Category).should be_false
    end

    it 'returns false when a regular user' do
      Guardian.new(user).can_create?(Category).should be_false
    end

    it 'returns true when a moderator' do
      Guardian.new(moderator).can_create?(Category).should be_true
    end

    it 'returns true when an admin' do
      Guardian.new(admin).can_create?(Category).should be_true
    end
  end

  describe 'can_edit_category?' do
    let(:category) { Fabricate(:category) }

    it 'returns false when not logged in' do
      Guardian.new.can_edit?(category).should be_false
    end

    it 'returns false as a regular user' do
      Guardian.new(category.user).can_edit?(category).should be_false
    end

    it 'returns true as a moderator' do
      Guardian.new(moderator).can_edit?(category).should be_true
    end

    it 'returns true as an admin' do
      Guardian.new(admin).can_edit?(category).should be_true
    end
  end

  context 'can_delete_category?' do
    let(:category) { build(:category, user: moderator) }

    it 'returns false when not logged in' do
      Guardian.new.can_delete?(category).should be_false
    end

    it 'returns false when a regular user' do
      Guardian.new(user).can_delete?(category).should be_false
    end

    it 'returns true when a moderator' do
      Guardian.new(moderator).can_delete?(category).should be_true
    end

    it 'returns true when an admin' do
      Guardian.new(admin).can_delete?(category).should be_true
    end

    it "can't be deleted if it has a forum topic" do
      category.topic_count = 10
      Guardian.new(moderator).can_delete?(category).should be_false
    end
  end
end
