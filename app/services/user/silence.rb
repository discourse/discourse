# frozen_string_literal: true

class User::Silence
  include Service::Base

  params do
    attribute :user_id, :integer
    attribute :reason, :string
    attribute :message, :string
    attribute :silenced_till, :datetime
    attribute :other_user_ids, :array
    attribute :post_id, :integer
    attribute :post_action, :string
    attribute :post_edit, :string
    attribute :reviewable_id, :integer

    validates :user_id, presence: true
    validates :reason, presence: true, length: { maximum: 300 }
    validates :silenced_till, presence: true
    validates :other_user_ids, length: { maximum: User::MAX_SIMILAR_USERS }
    validates :post_action,
              inclusion: {
                in: %w[delete delete_replies edit none],
              },
              allow_blank: true
  end

  options { attribute :raise_on_failure, :boolean, default: false }

  model :user
  policy :not_silenced_already, class_name: User::Policy::NotAlreadySilenced
  model :users
  policy :can_silence_all_users
  step :silence
  model :post, optional: true
  step :perform_post_action

  private

  def fetch_user(params:)
    User.find_by(id: params.user_id)
  end

  def fetch_users(user:, params:)
    [user, *User.where(id: params.other_user_ids.to_a.uniq).to_a]
  end

  def can_silence_all_users(guardian:, users:)
    users.all? { guardian.can_silence_user?(it) }
  end

  def silence(guardian:, users:, params:, options:)
    action =
      User::Action::SilenceAll.new(
        users:,
        actor: guardian.user,
        params:,
        raise_on_failure: options.raise_on_failure,
      )
    context[:full_reason] = action.call
    context[:restrictions] = action.restrictions
  end

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def perform_post_action(guardian:, post:, params:, options:)
    context[:restrictions].concat(
      User::Action::TriggerPostAction.call(
        guardian:,
        post:,
        params:,
        raise_on_failure: options.raise_on_failure,
      ),
    )
  end
end
