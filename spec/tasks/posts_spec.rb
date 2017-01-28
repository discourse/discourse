require 'rails_helper'

RSpec.describe "Post rake tasks" do
  before do
    Discourse::Application.load_tasks
    IO.any_instance.stubs(:puts)
  end

  describe 'remap' do
    it 'should remap posts' do
      post = Fabricate(:post, raw: "The quick brown fox jumps over the lazy dog")

      Rake::Task['posts:remap'].invoke("brown","red")
      post.reload
      expect(post.raw).to eq('The quick red fox jumps over the lazy dog')
    end
  end
end
