require 'rails_helper'

describe Admin::EmbeddingController do

  it "is a subclass of AdminController" do
    expect(Admin::EmbeddingController < Admin::AdminController).to eq(true)
  end

end
