require 'spec_helper'
require 'user_name_suggester'

describe UserNameSuggester do

  describe 'name heuristics' do
    it 'is able to guess a decent username from an email' do
      expect(UserNameSuggester.suggest('bob@bob.com')).to eq('bob')
    end
  end

  describe '.suggest' do
    before do
      User.stubs(:username_length).returns(3..15)
    end

    it "doesn't raise an error on nil username" do
      expect(UserNameSuggester.suggest(nil)).to eq(nil)
    end

    it 'corrects weird characters' do
      expect(UserNameSuggester.suggest("Darth%^Vader")).to eq('Darth_Vader')
    end

    it "transliterates some characters" do
      expect(UserNameSuggester.suggest("Jørn")).to eq('Jorn')
    end

    it 'adds 1 to an existing username' do
      user = Fabricate(:user)
      expect(UserNameSuggester.suggest(user.username)).to eq("#{user.username}1")
    end

    it "adds numbers if it's too short" do
      expect(UserNameSuggester.suggest('a')).to eq('a11')
    end

    it "has a special case for me and i emails" do
      expect(UserNameSuggester.suggest('me@eviltrout.com')).to eq('eviltrout')
      expect(UserNameSuggester.suggest('i@eviltrout.com')).to eq('eviltrout')
    end

    it "shortens very long suggestions" do
      expect(UserNameSuggester.suggest("myreallylongnameisrobinwardesquire")).to eq('myreallylongnam')
    end

    it "makes room for the digit added if the username is too long" do
      User.create(username: 'myreallylongnam', email: 'fake@discourse.org')
      expect(UserNameSuggester.suggest("myreallylongnam")).to eq('myreallylongna1')
    end

    it "doesn't suggest reserved usernames" do
      SiteSetting.reserved_usernames = 'admin|steve|steve1'
      expect(UserNameSuggester.suggest("admin@hissite.com")).to eq('admin1')
      expect(UserNameSuggester.suggest("steve")).to eq('steve2')
    end

    it "removes leading character if it is not alphanumeric" do
      expect(UserNameSuggester.suggest("_myname")).to eq('myname')
    end

    it "removes trailing characters if they are invalid" do
      expect(UserNameSuggester.suggest("myname!^$=")).to eq('myname')
    end

    it "replace dots" do
      expect(UserNameSuggester.suggest("my.name")).to eq('my_name')
    end

    it "remove leading dots" do
      expect(UserNameSuggester.suggest(".myname")).to eq('myname')
    end

    it "remove trailing dots" do
      expect(UserNameSuggester.suggest("myname.")).to eq('myname')
    end

    it 'handles usernames with a sequence of 2 or more special chars' do
      expect(UserNameSuggester.suggest('Darth__Vader')).to eq('Darth_Vader')
      expect(UserNameSuggester.suggest('Darth_-_Vader')).to eq('Darth_Vader')
    end

    it 'should handle typical facebook usernames' do
      expect(UserNameSuggester.suggest('roger.nelson.3344913')).to eq('roger_nelson_33')
    end
  end

end
