require 'spec_helper'

describe UsersController, :search_users do

  let(:topic)  { Fabricate :topic }
  let(:topic2) { Fabricate :topic }
  let(:topic3) { Fabricate :topic }
  let(:user1)  { Fabricate :user, username: "mrblonde", name: "Michael Madsen" }
  let(:user2)  { Fabricate :user, username: "mrblue",   name: "Eddie Bunker" }
  let(:user3)  { Fabricate :user, username: "mrorange", name: "Tim Roth" }
  let(:user4)  { Fabricate :user, username: "mrpink",   name: "Steve Buscemi" }
  let(:user5)  { Fabricate :user, username: "mrbrown",  name: "Quentin Tarantino" }
  let(:user6)  { Fabricate :user, username: "mrwhite",  name: "Harvey Keitel" }

  before do
    Fabricate :post, user: user1, topic: topic
    Fabricate :post, user: user2, topic: topic2
    Fabricate :post, user: user3, topic: topic
    Fabricate :post, user: user4, topic: topic
    Fabricate :post, user: user5, topic: topic3
    Fabricate :post, user: user6, topic: topic
  end

  context "all user search" do
    it "searches the user's name" do
      xhr :post, :search_users, term: user1.name.split(" ").first
      json = JSON.parse(response.body)
      json["users"].size.should == 1
      json["users"].first.should == user_json(user1)
    end

    it "searches the user's name case insensitive" do
      xhr :post, :search_users, term: user1.name.split(" ").first.downcase
      json = JSON.parse(response.body)
      json["users"].size.should == 1
      json["users"].first.should == user_json(user1)
    end

    it "searches the user's username" do
      xhr :post, :search_users, term: user4.username
      json = JSON.parse(response.body)
      json["users"].size.should == 1
      json["users"].first.should == user_json(user4)
    end

    it "searches the user's username case insensitive" do
      xhr :post, :search_users, term: user4.username.upcase
      json = JSON.parse(response.body)
      json["users"].size.should == 1
      json["users"].first.should == user_json(user4)
    end

    it "searches the user's username substring" do
      xhr :post, :search_users, term: "mr"
      json = JSON.parse(response.body)
      json["users"].size.should == 6

      xhr :post, :search_users, term: "mrb"
      json = JSON.parse(response.body)
      json["users"].size.should == 3
    end

    it "searches the user's username substring upper case" do
      xhr :post, :search_users, term: "MR"
      json = JSON.parse(response.body)
      json["users"].size.should == 6

      xhr :post, :search_users, term: "MRB"
      json = JSON.parse(response.body)
      json["users"].size.should == 3
    end
  end

  context "sort order respects users with posts on the topic" do
    it "Mr. Blond is first when searching his topic" do
      xhr :post, :search_users, topic_id: topic.id, term: "mrb"
      json = JSON.parse(response.body)
      json["users"].first.should == user_json(user1)
    end

    it "Mr. Blue is first when searching his topic" do
      xhr :post, :search_users, topic_id: topic2.id, term: "mrb"
      json = JSON.parse(response.body)
      json["users"].first.should == user_json(user2)
    end

    it "Mr. Brown is first when searching his topic" do
      xhr :post, :search_users, topic_id: topic3.id, term: "mrb"
      json = JSON.parse(response.body)
      json["users"].first.should == user_json(user5)
    end
  end

  def user_json user
    { "avatar_template" => user.avatar_template,
      "name"            => user.name,
      "username"        => user.username }
  end

end
