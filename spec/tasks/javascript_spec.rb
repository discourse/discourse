# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Javascript rake tasks" do

  test_git_hash = 'abcdef1234567890abcdef1234567890abcdef12'

  # before do
  #   Rake::Task.clear
  #   Discourse::Application.load_tasks
  #   StampedFiles.stubs(:git_hash).returns(test_git_hash)
  # end

  # after(:all) do
  #   StampedFiles.cleanup(0, test_git_hash)
  # end

  describe "javascript:update" do
    xit "creates the expected files" do
      capture_stdout do
        Rake::Task['javascript:update'].invoke
      end

      expect(Discourse.public_js_git_hash_stamp).to eq(test_git_hash)
      expect(Dir.glob(File.join(Rails.root, 'public', 'javascripts', "*#{test_git_hash}*")).length).to_not eq(0)
    end
  end
end
