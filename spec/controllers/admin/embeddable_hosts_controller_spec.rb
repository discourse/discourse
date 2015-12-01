require 'rails_helper'

describe Admin::EmbeddableHostsController do

  it "is a subclass of AdminController" do
    expect(Admin::EmbeddableHostsController < Admin::AdminController).to eq(true)
  end

end
