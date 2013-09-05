require 'spec_helper'

describe PostSerializer do

  context "a post by a nuked user" do
    let!(:post) { Fabricate(:post, user: Fabricate(:user), deleted_at: Time.zone.now) }

    before do
      post.user_id = nil
      post.save!
    end

    subject { PostSerializer.new(post, scope: Guardian.new(Fabricate(:admin)), root: false).as_json }

    it "serializes correctly" do
      [:name, :username, :display_username, :avatar_template].each do |attr|
        subject[attr].should be_nil
      end
      [:moderator?, :staff?, :yours, :user_title, :trust_level].each do |attr|
        subject[attr].should be_false
      end
    end
  end

end
