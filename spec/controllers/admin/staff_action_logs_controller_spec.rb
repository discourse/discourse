require 'spec_helper'

describe Admin::StaffActionLogsController do
  it "is a subclass of AdminController" do
    (Admin::StaffActionLogsController < Admin::AdminController).should be_true
  end

  let!(:user) { log_in(:admin) }

  context '.index' do
    before do
      xhr :get, :index
    end

    subject { response }
    it { should be_success }

    it 'returns JSON' do
      ::JSON.parse(subject.body).should be_a(Array)
    end
  end
end
