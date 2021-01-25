# frozen_string_literal: true

require 'rails_helper'

describe TimelineLookup do

  context '.build' do
    it 'keeps the last tuple in the lookup' do
      tuples = [
        [7173, 400], [7174, 390], [7175, 380], [7176, 370], [7177, 1]
      ]

      expect(TimelineLookup.build(tuples, 2)).to eq([[1, 400], [4, 370], [5, 1]])
    end
  end

end
