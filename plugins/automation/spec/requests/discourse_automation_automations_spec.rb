# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe DiscourseAutomation::AdminDiscourseAutomationAutomationsController do
  describe '#trigger' do
    fab!(:automation) { Fabricate(:automation) }

    describe 'access' do
      context 'user is not logged in' do
        before { sign_out }

        it 'raises a 404' do
          post "/automations/#{automation.id}/trigger.json"
          expect(response.status).to eq(404)
        end
      end

      context 'user is logged in' do
        context 'user is admin' do
          before { sign_in(Fabricate(:admin)) }

          it 'triggers the automation' do
            output = JSON.parse(capture_stdout do
              post "/automations/#{automation.id}/trigger.json"
            end)

            expect(output['kind']).to eq('api_call')
          end
        end

        context 'user is moderator' do
          before { sign_in(Fabricate(:moderator)) }

          it 'raises a 404' do
            post "/automations/#{automation.id}/trigger.json"
            expect(response.status).to eq(404)
          end
        end

        context 'user is regular' do
          before { sign_in(Fabricate(:user)) }

          it 'raises a 404' do
            post "/automations/#{automation.id}/trigger.json"
            expect(response.status).to eq(404)
          end
        end
      end

      context 'using a user api key' do
        before { sign_out }

        let(:admin) { Fabricate(:admin) }
        let(:api_key) { Fabricate(:api_key, user: admin) }

        it 'works' do
          post "/automations/#{automation.id}/trigger.json", {
            params: { context: { foo: :bar } },
            headers: {
              HTTP_API_KEY: api_key.key
            }
          }
          expect(response.status).to eq(200)
        end
      end
    end

    describe 'params as context' do
      fab!(:admin) { Fabricate(:admin) }
      fab!(:automation) { Fabricate(:automation, script: 'something_about_us', trigger: 'api_call') }

      before do
        sign_in(admin)
      end

      it 'passes the params' do
        output = JSON.parse(capture_stdout do
          post "/automations/#{automation.id}/trigger.json", { params: { foo: '1', bar: '2' } }
        end)

        expect(output['foo']).to eq('1')
        expect(output['bar']).to eq('2')
        expect(response.status).to eq(200)
      end
    end
  end
end
