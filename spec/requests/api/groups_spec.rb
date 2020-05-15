# frozen_string_literal: true
require 'swagger_helper'

describe 'groups' do

  let(:admin) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path '/admin/groups.json' do

    post 'Creates a group' do
      tags 'Group'
      consumes 'application/json'
      parameter name: :group, in: :body, schema: {
        type: :object,
        properties: {
          group: {
            type: :object,
            properties: {
              name: { type: :string },
            }, required: [ 'name' ]
          }
        },
      }

      produces 'application/json'
      response '200', 'group created' do
        schema type: :object, properties: {
            basic_group: {
              type: :object,
              properties: {
                id: { type: :integer },
                automatic: { type: :boolean },
                name: { type: :string },
                user_count: { type: :integer },
                mentionable_level: { type: :integer },
                messageable_level: { type: :integer },
                visibility_level: { type: :integer },
                automatic_membership_email_domains: { type: :string, nullable: true },
                automatic_membership_retroactive: { type: :boolean },
                primary_group: { type: :boolean },
                title: { type: :string, nullable: true },
                grant_trust_level: { type: :string, nullable: true },
                incoming_email: { type: :string, nullable: true },
                has_messages: { type: :boolean },
                flair_url: { type: :string, nullable: true },
                flair_bg_color: { type: :string, nullable: true },
                flair_color: { type: :string, nullable: true },
                bio_raw: { type: :string, nullable: true },
                bio_cooked: { type: :string, nullable: true },
                bio_excerpt: { type: :string, nullable: true },
                public_admission: { type: :boolean },
                public_exit: { type: :boolean },
                allow_membership_requests: { type: :boolean },
                full_name: { type: :string, nullable: true },
                default_notification_level: { type: :integer },
                membership_request_template: { type: :string, nullable: true },
                membership_visibility_level: { type: :integer },
                can_see_members: { type: :boolean },
                publish_read_state: { type: :boolean },
              },
              required: ["id"]
            }
          }, required: ["basic_group"]

        let(:group) { { name: 'awesome' } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['basic_group']['name']).to eq("awesome")
        end
      end
    end

  end
end
