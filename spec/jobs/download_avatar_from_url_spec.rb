# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::DownloadAvatarFromUrl do
  fab!(:user) { Fabricate(:user) }

  describe 'when url is invalid' do
    it 'should not raise any error' do
      expect do
        described_class.new.execute(
          url: '/assets/something/nice.jpg',
          user_id: user.id
        )
      end.to_not raise_error
    end
  end
end
