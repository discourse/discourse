require 'spec_helper'
require 'user_name_suggester'

describe UserNameSuggester do

  describe 'name heuristics' do
    it 'is able to guess a decent username from an email' do
      UserNameSuggester.suggest('bob@bob.com').should == 'bob'
    end
  end

  describe '.suggest' do
    before do
      User.stubs(:username_length).returns(3..15)
    end

    it "doesn't raise an error on nil username" do
      UserNameSuggester.suggest(nil).should be_nil
    end

    it 'corrects weird characters' do
      UserNameSuggester.suggest("Darth%^Vader").should == 'Darth_Vader'
    end

    it 'adds 1 to an existing username' do
      user = Fabricate(:user)
      UserNameSuggester.suggest(user.username).should == "#{user.username}1"
    end

    it "adds numbers if it's too short" do
      UserNameSuggester.suggest('a').should == 'a11'
    end

    it "has a special case for me and i emails" do
      UserNameSuggester.suggest('me@eviltrout.com').should == 'eviltrout'
      UserNameSuggester.suggest('i@eviltrout.com').should == 'eviltrout'
    end

    it "shortens very long suggestions" do
      UserNameSuggester.suggest("myreallylongnameisrobinwardesquire").should == 'myreallylongnam'
    end

    it "makes room for the digit added if the username is too long" do
      User.create(username: 'myreallylongnam', email: 'fake@discourse.org')
      UserNameSuggester.suggest("myreallylongnam").should == 'myreallylongna1'
    end

    it "removes leading character if it is not alphanumeric" do
      UserNameSuggester.suggest("_myname").should == 'myname'
    end

    it "removes trailing characters if they are invalid" do
      UserNameSuggester.suggest("myname!^$=").should == 'myname'
    end

    it "replace dots" do
      UserNameSuggester.suggest("my.name").should == 'my_name'
    end

    it "remove leading dots" do
      UserNameSuggester.suggest(".myname").should == 'myname'
    end

    it "remove trailing dots" do
      UserNameSuggester.suggest("myname.").should == 'myname'
    end

    it 'should handle typical facebook usernames' do
      UserNameSuggester.suggest('roger.nelson.3344913').should == 'roger_nelson_33'
    end
  end

end
