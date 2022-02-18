# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'
require 'archetype'

describe Archetype do

  context 'default archetype' do

    it 'has an Archetype by default' do
      expect(Archetype.list).to be_present
    end

    it 'has an id of default' do
      expect(Archetype.list.first.id).to eq(Archetype.default)
    end

    context 'duplicate' do

      before do
        @old_size = Archetype.list.size
        Archetype.register(Archetype.default)
      end

      it 'does not add the same archetype twice' do
        expect(Archetype.list.size).to eq(@old_size)
      end

    end

  end

  context 'register an archetype' do

    it 'has one more element' do
      @list = Archetype.list.dup
      Archetype.register('glados')
      expect(Archetype.list.size).to eq(@list.size + 1)
      expect(Archetype.list.find { |a| a.id == 'glados' }).to be_present
    end

  end

end
