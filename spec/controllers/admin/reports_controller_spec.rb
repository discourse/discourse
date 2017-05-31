require 'rails_helper'

describe Admin::ReportsController do
  it "is a subclass of AdminController" do
    expect(Admin::ReportsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    let!(:admin) { log_in(:admin) }
    let(:user) { Fabricate(:user) }


    context '.show' do

      context "invalid id form" do
        let(:invalid_id) { "!!&asdfasdf" }

        it "never calls Report.find" do
          Report.expects(:find).never
          xhr :get, :show, type: invalid_id
        end

        it "returns 404" do
          xhr :get, :show, type: invalid_id
          expect(response.status).to eq(404)
        end
      end

      context "valid type form" do

        context 'missing report' do
          before do
            Report.expects(:find).with('active', instance_of(Hash)).returns(nil)
            xhr :get, :show, type: 'active'
          end

          it "renders the report as JSON" do
            expect(response.status).to eq(404)
          end
        end

        context 'a report is found' do
          before do
            Report.expects(:find).with('active', instance_of(Hash)).returns(Report.new('active'))
            xhr :get, :show, type: 'active'
          end

          it "renders the report as JSON" do
            expect(response).to be_success
          end

          it "renders the report as JSON" do
            expect(::JSON.parse(response.body)).to be_present
          end

        end

      end

      describe 'when report is scoped to a category' do
        let(:category) { Fabricate(:category) }
        let(:topic) { Fabricate(:topic, category: category) }
        let(:other_topic) { Fabricate(:topic) }

        it 'should render the report as JSON' do
          topic
          other_topic

          xhr :get, :show, type: 'topics', category_id: category.id

          expect(response).to be_success

          report = JSON.parse(response.body)["report"]

          expect(report["type"]).to eq('topics')
          expect(report["data"].count).to eq(1)
        end
      end

      describe 'when report is scoped to a group' do
        let(:user) { Fabricate(:user) }
        let(:other_user) { Fabricate(:user) }
        let(:group) { Fabricate(:group) }

        it 'should render the report as JSON' do
          other_user
          group.add(user)

          xhr :get, :show, type: 'signups', group_id: group.id

          expect(response).to be_success

          report = JSON.parse(response.body)["report"]

          expect(report["type"]).to eq('signups')
          expect(report["data"].count).to eq(1)
        end
      end

    end

  end

end
