require 'rails_helper'
require 'highline/import'
require 'highline/simulate'

RSpec.describe "Post rake tasks" do
  before do
    Rake::Task.clear
    Discourse::Application.load_tasks
    IO.any_instance.stubs(:puts)
  end

  describe 'remap' do
    let!(:tricky_post) { Fabricate(:post, raw: 'Today ^Today') }

    it 'should remap posts' do
      post = Fabricate(:post, raw: "The quick brown fox jumps over the lazy dog")

      HighLine::Simulate.with('y') do
        Rake::Task['posts:remap'].invoke("brown", "red")
      end

      post.reload
      expect(post.raw).to eq('The quick red fox jumps over the lazy dog')
    end

    context 'when type == string' do
      it 'remaps input as string' do
        HighLine::Simulate.with('y') do
          Rake::Task['posts:remap'].invoke('^Today', 'Yesterday', 'string')
        end

        expect(tricky_post.reload.raw).to eq('Today Yesterday')
      end
    end

    context 'when type == regex' do
      it 'remaps input as regex' do
        HighLine::Simulate.with('y') do
          Rake::Task['posts:remap'].invoke('^Today', 'Yesterday', 'regex')
        end

        expect(tricky_post.reload.raw).to eq('Yesterday ^Today')
      end
    end
  end
end
