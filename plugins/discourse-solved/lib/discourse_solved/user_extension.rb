# frozen_string_literal: true

module DiscourseSolved::UserExtension
  extend ActiveSupport::Concern

  prepended do
    has_many :discourse_solved_me_toos, class_name: "DiscourseSolved::MeToo", dependent: :delete_all
  end
end
