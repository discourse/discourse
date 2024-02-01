# frozen_string_literal: true

module DiscoursePoll
  module UserExtension
    extend ActiveSupport::Concern

    prepended { has_many :poll_votes, dependent: :delete_all }
  end
end
