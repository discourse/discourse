require 'rails_helper'
require_dependency 'user'

describe AdminUserListSerializer do

  context "emails" do
    let(:admin) { Fabricate(:user_single_email, admin: true, email: "admin@email.com") }
    let(:user) { Fabricate(:user_single_email, email: "user@email.com") }
    let(:guardian) { Guardian.new(admin) }

    let(:json) do
      AdminUserListSerializer.new(user,
        scope: guardian,
        root: false
      ).as_json
    end

    def fabricate_secondary_emails_for(u)
      ["first", "second"].each do |name|
        Fabricate(:secondary_email, user: u, email: "#{name}@email.com")
      end
    end

    shared_examples "shown" do |email|
      it "contains emails" do
        expect(json[:email]).to eq(email)

        expect(json[:secondary_emails]).to contain_exactly(
          "first@email.com",
          "second@email.com"
        )
      end
    end

    shared_examples "not shown" do
      it "doesn't contain emails" do
        expect(json[:email]).to eq(nil)
        expect(json[:secondary_emails]).to eq(nil)
      end
    end

    context "with myself" do
      let(:user) { admin }

      before do
        fabricate_secondary_emails_for(admin)
      end

      include_examples "shown", "admin@email.com"
    end

    context "with a normal user" do
      before do
        fabricate_secondary_emails_for(user)
      end

      include_examples "not shown"
    end

    context "with a normal user after clicking 'show emails'" do
      before do
        guardian.can_see_emails = true
        fabricate_secondary_emails_for(user)
      end

      include_examples "shown", "user@email.com"
    end

    context "with a staged user" do
      before do
        user.staged = true
        fabricate_secondary_emails_for(user)
      end

      include_examples "shown", "user@email.com"
    end
  end
end
