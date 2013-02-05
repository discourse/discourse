# encoding: utf-8

require 'spec_helper'
require 'archetype'

describe Archetype do

  context 'default archetype' do

    it 'has an Archetype by default' do
      Archetype.list.should be_present
    end

    it 'has an id of default' do
      Archetype.list.first.id.should == Archetype.default
    end

    context 'duplicate' do

      before do
        @old_size = Archetype.list.size
        Archetype.register(Archetype.default)
      end

      it 'does not add the same archetype twice' do
        Archetype.list.size.should == @old_size
      end

    end

  end

  context 'register an archetype' do

    before do
      @list = Archetype.list.dup
      Archetype.register('glados')
    end

    it 'has one more element' do
      Archetype.list.size.should == @list.size + 1
    end

    it 'has a glados element' do
      Archetype.list.find {|a| a.id == 'glados'}.should be_present
    end

  end

end

