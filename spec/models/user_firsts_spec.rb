require 'rails_helper'

describe UserFirst do

  let(:user) { Fabricate(:user) }

  context "#create_for" do
    it "doesn't raise an error on duplicate" do
      expect(UserFirst.create_for(user.id, :used_emoji)).to eq(true)
      expect(UserFirst.create_for(user.id, :used_emoji)).to eq(false)
    end
  end

  it "creates one the first time a user posts an emoji" do
    post = PostCreator.create(user, title: "this topic is about candy", raw: "time to eat some sweet :candy: mmmm")

    uf = UserFirst.where(user_id: user.id, first_type: UserFirst.types[:used_emoji]).first
    expect(uf).to be_present
    expect(uf.post_id).to eq(post.id)
  end

  context 'mentioning' do
    let(:codinghorror) { Fabricate(:codinghorror) }

    it "creates one the first time a user mentions another" do
      post = PostCreator.create(user, title: "gonna mention another user", raw: "what is up @codinghorror?")
      uf = UserFirst.where(user_id: user.id, first_type: UserFirst.types[:mentioned_user]).first
      expect(uf).to be_present
      expect(uf.post_id).to eq(post.id)
    end
  end

  context "privacy" do
    let(:codinghorror) { Fabricate(:codinghorror) }

    it "doesn't create the userfirst on private posts" do
      post = PostCreator.create(user,
                                archetype: Archetype.private_message,
                                target_usernames: ['codinghorror'],
                                title: "this topic is about candy",
                                raw: "time to eat some sweet :candy: mmmm")

      uf = UserFirst.where(user_id: user.id, first_type: UserFirst.types[:used_emoji]).first
      expect(uf).to be_blank
    end
  end
end
