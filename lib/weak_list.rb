# frozen_string_literal: true

require "weakref"

class WeakList
  include Enumerable

  def initialize
    @items = []
  end

  def <<(item)
    @items << WeakRef.new(item)
  end

  def to_a
    @items.select!(&:weakref_alive?)

    @items.filter_map do |ref|
      begin
        ref.__getobj__
      rescue WeakRef::RefError
      end
    end
  end

  def each(&blk)
    to_a.each(&blk)
  end
end
