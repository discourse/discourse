require 'spec_helper'

describe TopicGuardian do
  let(:user) { build(:user) }
  let(:moderator) { build(:moderator) }
  let(:admin) { build(:admin) }
  let(:coding_horror) { build(:coding_horror) }

  let(:topic) { build(:topic, user: user) }

  describe 'can_create_topic?' do
    it 'should check for full permissions' do
      category = Fabricate(:category)
      category.set_permissions(:everyone => :create_post)
      category.save
      Guardian.new(user).can_create?(Topic,category).should be_false
    end
  end
  
  describe 'can_edit_topic?' do
    it 'returns false when not logged in' do
      Guardian.new.can_edit?(topic).should be_false
    end

    it 'returns true for editing your own post' do
      Guardian.new(topic.user).can_edit?(topic).should be_true
    end


    it 'returns false as a regular user' do
      Guardian.new(coding_horror).can_edit?(topic).should be_false
    end

    context 'not archived' do
      it 'returns true as a moderator' do
        Guardian.new(moderator).can_edit?(topic).should be_true
      end

      it 'returns true as an admin' do
        Guardian.new(admin).can_edit?(topic).should be_true
      end
    end

    context 'archived' do
      it 'returns false as a moderator' do
        Guardian.new(moderator).can_edit?(build(:topic, user: user, archived: true)).should be_false
      end

      it 'returns false as an admin' do
        Guardian.new(admin).can_edit?(build(:topic, user: user, archived: true)).should be_false
      end
    end
  end

  describe 'can_delete_topic?' do
    it 'returns false when not logged in' do
      Guardian.new.can_delete?(topic).should be_false
    end

    it 'returns false when not a moderator' do
      Guardian.new(user).can_delete?(topic).should be_false
    end

    it 'returns true when a moderator' do
      Guardian.new(moderator).can_delete?(topic).should be_true
    end

    it 'returns true when an admin' do
      Guardian.new(admin).can_delete?(topic).should be_true
    end
  end

  describe "can_recover_topic?" do
    it "returns false for a nil user" do
      Guardian.new(nil).can_recover_topic?(topic).should be_false
    end

    it "returns false for a nil object" do
      Guardian.new(user).can_recover_topic?(nil).should be_false
    end

    it "returns false for a regular user" do
      Guardian.new(user).can_recover_topic?(topic).should be_false
    end

    it "returns true for a moderator" do
      Guardian.new(moderator).can_recover_topic?(topic).should be_true
    end
  end

  describe 'can_reply_as_new_topic?' do
    let(:user) { Fabricate(:user) }
    let(:topic) { Fabricate(:topic) }

    it "returns false for a non logged in user" do
      Guardian.new(nil).can_reply_as_new_topic?(topic).should be_false
    end

    it "returns false for a nil topic" do
      Guardian.new(user).can_reply_as_new_topic?(nil).should be_false
    end

    it "returns false for an untrusted user" do
      user.trust_level = TrustLevel.levels[:new]
      Guardian.new(user).can_reply_as_new_topic?(topic).should be_false
    end

    it "returns true for a trusted user" do
      Guardian.new(user).can_reply_as_new_topic?(topic).should be_true
    end
  end

  describe 'can_see_topic?' do
    it 'allows non logged in users to view topics' do
      Guardian.new.can_see?(topic).should be_true
    end

    it 'correctly handles groups' do
      group = Fabricate(:group)
      category = Fabricate(:category, read_restricted: true)
      category.set_permissions(group => :full)
      category.save

      topic = Fabricate(:topic, category: category)

      Guardian.new(user).can_see?(topic).should be_false
      group.add(user)
      group.save

      Guardian.new(user).can_see?(topic).should be_true
    end
  end
end
