require 'spec_helper'

describe Admin::EmailController do

  it "is a subclass of AdminController" do
    (Admin::EmailController < Admin::AdminController).should be_true
  end

  let!(:user) { log_in(:admin) }

  context '.index' do
    before do
      xhr :get, :index
    end

    subject { response }
    it { should be_success }
  end

  context '.logs' do
    before do
      xhr :get, :logs
    end

    subject { response }
    it { should be_success }
  end

  context '.test' do
    it 'raises an error without the email parameter' do
      lambda { xhr :post, :test }.should raise_error(ActionController::ParameterMissing)
    end

    context 'with an email address' do
      it 'enqueues a test email job' do
        Jobs.expects(:enqueue).with(:test_email, to_address: 'eviltrout@test.domain')
        xhr :post, :test, email_address: 'eviltrout@test.domain'
      end
    end
  end

  context '.preview_digest' do
    it 'raises an error without the last_seen_at parameter' do
      lambda { xhr :get, :preview_digest }.should raise_error(ActionController::ParameterMissing)
    end

    it "previews the digest" do
      xhr :get, :preview_digest, last_seen_at: 1.week.ago
      expect(response).to be_success
    end
  end

end
