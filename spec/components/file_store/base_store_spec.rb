require 'rails_helper'
require_dependency 'file_store/base_store'

RSpec.describe FileStore::BaseStore do
  let(:upload) { Fabricate(:upload, id: 9999, sha1: Digest::SHA1.hexdigest('9999')) }

  describe '#get_depth_for' do
    describe 'when id is negative' do
      it 'should return the right depth' do
        expect(FileStore::BaseStore.new.get_depth_for(-999)).to eq(0)
      end
    end
  end

  describe '#get_path_for_upload' do
    it 'should return the right path' do
      expect(FileStore::BaseStore.new.get_path_for_upload(upload))
        .to eq('original/2X/4/4170ac2a2782a1516fe9e13d7322ae482c1bd594.png')
    end

    describe 'when Upload#extension has not been set' do
      it 'should return the right path' do
        upload.update!(extension: nil)

        expect(FileStore::BaseStore.new.get_path_for_upload(upload))
          .to eq('original/2X/4/4170ac2a2782a1516fe9e13d7322ae482c1bd594.png')
      end
    end
  end
end
