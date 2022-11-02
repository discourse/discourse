# frozen_string_literal: true

RSpec.describe ComposerController do
  describe '#mentions' do
    fab!(:user) { Fabricate(:user) }

    fab!(:group) { Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone], mentionable_level: Group::ALIAS_LEVELS[:everyone]) }
    fab!(:invisible_group) { Fabricate(:group, visibility_level: Group.visibility_levels[:owners]) }
    fab!(:unmessageable_group) { Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:nobody], mentionable_level: Group::ALIAS_LEVELS[:everyone]) }
    fab!(:unmentionable_group) { Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone], mentionable_level: Group::ALIAS_LEVELS[:nobody]) }

    before do
      sign_in(Fabricate(:user))
    end

    context 'with a regular topic' do
      fab!(:topic) { Fabricate(:topic) }

      it 'finds mentions' do
        get '/composer/mentions.json', params: {
          names: [
            'invaliduserorgroup',
            user.username,
            group.name,
            invisible_group.name,
            unmessageable_group.name,
            unmentionable_group.name
          ],
        }

        expect(response.parsed_body['users']).to contain_exactly(user.username)
        expect(response.parsed_body['user_reasons']).to contain_exactly()

        expect(response.parsed_body['groups']).to contain_exactly(
          [group.name, { "user_count" => group.user_count }],
          [unmessageable_group.name, { "user_count" => unmessageable_group.user_count }],
          [unmentionable_group.name, { "user_count" => unmentionable_group.user_count }],
        )
        expect(response.parsed_body['group_reasons']).to contain_exactly(
          [unmentionable_group.name, "not_mentionable"],
        )

        expect(response.parsed_body['max_users_notified_per_group_mention'])
          .to eq(SiteSetting.max_users_notified_per_group_mention)
      end
    end

    context 'with a private message' do
      fab!(:allowed_user) { Fabricate(:user) }
      fab!(:topic) { Fabricate(:private_message_topic, user: allowed_user) }

      it 'does not work if topic is not visible' do
        get '/composer/mentions.json', params: {
          names: [allowed_user.username], topic_id: topic.id
        }

        expect(response.status).to eq(403)
      end

      it 'finds mentions' do
        sign_in(allowed_user)
        topic.invite_group(Discourse.system_user, unmentionable_group)

        get '/composer/mentions.json', params: {
          names: [
            'invaliduserorgroup',
            user.username,
            allowed_user.username,
            group.name,
            invisible_group.name,
            unmessageable_group.name,
            unmentionable_group.name
          ],
          topic_id: topic.id,
        }

        expect(response.parsed_body['users']).to contain_exactly(
          user.username, allowed_user.username
        )
        expect(response.parsed_body['user_reasons']).to contain_exactly(
          [user.username, "private"]
        )

        expect(response.parsed_body['groups']).to contain_exactly(
          [group.name, { "user_count" => group.user_count }],
          [unmessageable_group.name, { "user_count" => unmessageable_group.user_count }],
          [unmentionable_group.name, { "user_count" => unmentionable_group.user_count }],
        )
        expect(response.parsed_body['group_reasons']).to contain_exactly(
          [group.name, "not_allowed"],
          [unmessageable_group.name, "not_allowed"],
          [unmentionable_group.name, "not_mentionable"],
        )

        expect(response.parsed_body['max_users_notified_per_group_mention'])
          .to eq(SiteSetting.max_users_notified_per_group_mention)
      end
    end

    context 'with a new topic' do
      fab!(:allowed_user) { Fabricate(:user) }

      it 'finds mentions' do
        get '/composer/mentions.json', params: {
          names: [
            'invaliduserorgroup',
            user.username,
            allowed_user.username,
            group.name,
            invisible_group.name,
            unmessageable_group.name,
            unmentionable_group.name
          ],
          allowed_names: "#{allowed_user.username},#{unmentionable_group.name}",
        }

        expect(response.parsed_body['users']).to contain_exactly(
          user.username, allowed_user.username
        )
        expect(response.parsed_body['user_reasons']).to contain_exactly(
          [user.username, "private"]
        )

        expect(response.parsed_body['groups']).to contain_exactly(
          [group.name, { "user_count" => group.user_count }],
          [unmessageable_group.name, { "user_count" => unmessageable_group.user_count }],
          [unmentionable_group.name, { "user_count" => unmentionable_group.user_count }],
        )
        expect(response.parsed_body['group_reasons']).to contain_exactly(
          [group.name, "not_allowed"],
          [unmessageable_group.name, "not_allowed"],
          [unmentionable_group.name, "not_mentionable"],
        )

        expect(response.parsed_body['max_users_notified_per_group_mention'])
          .to eq(SiteSetting.max_users_notified_per_group_mention)
      end
    end
  end
end
