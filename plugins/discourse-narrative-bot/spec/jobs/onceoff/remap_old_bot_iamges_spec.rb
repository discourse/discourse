# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::DiscourseNarrativeBot::RemapOldBotImages do
  context "when bot's post contains an old link" do
    let(:post) do
      Fabricate(:post,
        user: ::DiscourseNarrativeBot::Base.new.discobot_user,
        raw: 'If you’d like to learn more, select <img src="/images/font-awesome-gear.png" width="16" height="16"> <img src="/images/font-awesome-ellipsis.png" width="16" height="16"> below  and <img src="/images/font-awesome-bookmark.png" width="16" height="16"> **bookmark this private message**.  If you do, there may be a :gift: in your future!'
      )
    end

    before do
      post
    end

    it 'should remap the links correctly' do
      expected_raw = 'If you’d like to learn more, select <img src="/plugins/discourse-narrative-bot/images/font-awesome-gear.png" width="16" height="16"> <img src="/plugins/discourse-narrative-bot/images/font-awesome-ellipsis.png" width="16" height="16"> below  and <img src="/plugins/discourse-narrative-bot/images/font-awesome-bookmark.png" width="16" height="16"> **bookmark this private message**.  If you do, there may be a :gift: in your future!'

      2.times do
        described_class.new.execute_onceoff({})
        expect(post.reload.raw).to eq(expected_raw)
      end
    end

    context 'subfolder' do
      let(:post) do
        Fabricate(:post,
          user: ::DiscourseNarrativeBot::Base.new.discobot_user,
          raw: 'If you’d like to learn more, select <img src="/community/images/font-awesome-ellipsis.png" width="16" height="16"> below  and <img src="/community/images/font-awesome-bookmark.png" width="16" height="16"> **bookmark this private message**.  If you do, there may be a :gift: in your future!'
        )
      end

      it 'should remap the links correctly' do
        described_class.new.execute_onceoff({})

        expect(post.reload.raw).to eq(
          'If you’d like to learn more, select <img src="/community/plugins/discourse-narrative-bot/images/font-awesome-ellipsis.png" width="16" height="16"> below  and <img src="/community/plugins/discourse-narrative-bot/images/font-awesome-bookmark.png" width="16" height="16"> **bookmark this private message**.  If you do, there may be a :gift: in your future!'
        )
      end
    end
  end
end
