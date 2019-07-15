# frozen_string_literal: true

require 'rails_helper'

describe ThemesInstallTask do

  before do
    Discourse::Application.load_tasks
  end

  let(:github_repo) { 'https://github.com/example/theme.git' }
  let(:branch) { 'master' }

  describe '.new' do
    context 'with url' do
      subject { described_class.new(github_repo) }

      it 'configures the url' do
        expect(subject.url).to eq github_repo
      end

      it 'initializes without options' do
        expect(subject.options).to eq({})
      end
    end

    context 'with options' do
      subject { described_class.new(options) }
      let(:options) { { 'url' => github_repo, 'branch' => branch } }

      it 'configures the url' do
        expect(subject.url).to eq github_repo
      end

      it 'initializes options' do
        expect(subject.options).to eq("url" => github_repo, "branch" => branch)
      end
    end
  end

  describe '#theme_exists?' do
    let(:theme) { Fabricate(:theme) }
    subject { described_class.new(options) }

    context 'without branch' do
      let(:options) { github_repo }

      it 'returns true when a branchless theme exists' do
        theme.create_remote_theme(remote_url: github_repo)
        expect(subject.theme_exists?).to be true
      end

      it 'returns false when the url exists but with a branch' do
        theme.create_remote_theme(remote_url: github_repo, branch: branch)
        expect(subject.theme_exists?).to be false
      end

      it 'returns false when it doesnt exist' do
        theme.create_remote_theme(remote_url: 'https://github.com/example/different_theme.git')
        expect(subject.theme_exists?).to be false
      end
    end

    context 'with branch' do
      let(:options) { { 'url' => github_repo, 'branch' => branch } }

      it 'returns false when a branchless theme exists' do
        theme.create_remote_theme(remote_url: github_repo)
        expect(subject.theme_exists?).to be false
      end

      it 'returns true when the url exists with a branch' do
        theme.create_remote_theme(remote_url: github_repo, branch: branch)
        expect(subject.theme_exists?).to be true
      end

      it 'returns false when it doesnt exist' do
        theme.create_remote_theme(remote_url: 'https://github.com/example/different_theme.git')
        expect(subject.theme_exists?).to be false
      end
    end
  end
end
