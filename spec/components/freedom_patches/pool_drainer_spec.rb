require 'rails_helper'

describe 'pool drainer' do
  let(:pool) do
    ActiveRecord::Base.connection_pool
  end

  it 'can correctly drain the connection pool' do
    pool.drain
    old = pool.connections.length
    expect(old).to eq(1)

    Thread.new do
      conn = pool.checkout
      pool.checkin conn
    end.join

    expect(pool.connections.length).to eq(old+1)
    pool.drain
    expect(pool.connections.length).to eq(old)
  end

  it 'can drain with idle time setting' do
    pool.drain
    old = pool.connections.length
    expect(old).to eq(1)


    Thread.new do
      conn = pool.checkout
      pool.checkin conn
    end.join

    expect(pool.connections.length).to eq(old+1)
    pool.drain(1.minute)
    expect(pool.connections.length).to eq(old+1)

    # make sure we don't corrupt internal state
    20.times do
      conn = pool.checkout
      pool.checkin conn
      pool.drain
    end

  end

end
