require 'spec_helper'
require_dependency 'post_action'

describe PostSerializer do

  context "a post with lots of actions" do
    let(:post) { Fabricate(:post) }
    let(:actor) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let(:acted_ids) {
      PostActionType.public_types.values
        .concat([:notify_user,:spam]
        .map{|k| PostActionType.types[k]})
    }

    def visible_actions_for(user)
      serializer = PostSerializer.new(post, scope: Guardian.new(user), root: false)
      # NOTE this is messy, we should extract all this logic elsewhere
      serializer.post_actions = PostAction.counts_for([post], actor)[post.id] if user.try(:id) == actor.id
      actions = serializer.as_json[:actions_summary]
      lookup = PostActionType.types.invert
      actions.keep_if{|a| a[:count] > 0}.map{|a| lookup[a[:id]]}
    end

    before do
      acted_ids.each do|id|
        PostAction.act(actor, post, id)
      end
      post.reload
    end

    it "displays the correct info" do
      visible_actions_for(actor).sort.should == [:like,:notify_user,:spam,:vote]
      visible_actions_for(post.user).sort.should == [:like,:vote]
      visible_actions_for(nil).sort.should == [:like,:vote]
      visible_actions_for(admin).sort.should == [:like,:notify_user,:spam,:vote]
    end

  end

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

  context "display_username" do
    let(:user) { Fabricate.build(:user) }
    let(:post) { Fabricate.build(:post, user: user) }
    let(:serializer) { PostSerializer.new(post, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "returns the display_username it when `enable_names` is on" do
      SiteSetting.stubs(:enable_names).returns(true)
      json[:display_username].should be_present
    end

    it "doesn't return the display_username it when `enable_names` is off" do
      SiteSetting.stubs(:enable_names).returns(false)
      json[:display_username].should be_blank
    end
  end

  context "a hidden post with add_raw enabled" do
    let(:user) { Fabricate.build(:user) }
    let(:raw)  { "Raw contents of the post." }

    def serialized_post_for_user(u)
      s = PostSerializer.new(post, scope: Guardian.new(u), root: false)
      s.add_raw = true
      s.as_json
    end

    context "a public post" do
      let(:post) { Fabricate.build(:post, raw: raw, user: user) }

      it "includes the raw post for everyone" do
        [nil, user, Fabricate(:user), Fabricate(:moderator), Fabricate(:admin)].each do |user|
          serialized_post_for_user(user)[:raw].should == raw
        end
      end
    end

    context "a hidden post" do
      let(:post) { Fabricate.build(:post, raw: raw, user: user, hidden: true, hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached]) }

      it "shows the raw post only if authorized to see it" do
        serialized_post_for_user(nil)[:raw].should be_nil
        serialized_post_for_user(Fabricate(:user))[:raw].should be_nil

        serialized_post_for_user(user)[:raw].should == raw
        serialized_post_for_user(Fabricate(:moderator))[:raw].should == raw
        serialized_post_for_user(Fabricate(:admin))[:raw].should == raw
      end

      it "can view edit history only if authorized" do
        serialized_post_for_user(nil)[:can_view_edit_history].should == false
        serialized_post_for_user(Fabricate(:user))[:can_view_edit_history].should == false

        serialized_post_for_user(user)[:can_view_edit_history].should == true
        serialized_post_for_user(Fabricate(:moderator))[:can_view_edit_history].should == true
        serialized_post_for_user(Fabricate(:admin))[:can_view_edit_history].should == true
      end
    end

    context "a public wiki post" do
      let(:post) { Fabricate.build(:post, raw: raw, user: user, wiki: true) }

      it "can view edit history" do
        [nil, user, Fabricate(:user), Fabricate(:moderator), Fabricate(:admin)].each do |user|
          serialized_post_for_user(user)[:can_view_edit_history].should == true
        end
      end
    end

    context "a hidden wiki post" do
      let(:post) { Fabricate.build(:post, raw: raw, user: user, wiki: true, hidden: true, hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached]) }

      it "can view edit history only if authorized" do
        serialized_post_for_user(nil)[:can_view_edit_history].should == false
        serialized_post_for_user(Fabricate(:user))[:can_view_edit_history].should == false

        serialized_post_for_user(user)[:can_view_edit_history].should == true
        serialized_post_for_user(Fabricate(:moderator))[:can_view_edit_history].should == true
        serialized_post_for_user(Fabricate(:admin))[:can_view_edit_history].should == true
      end
    end


  end

end
