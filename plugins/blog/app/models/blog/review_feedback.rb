# frozen_string_literal: true

module ::Blog
  class ReviewFeedback < ActiveRecord::Base
    self.table_name = "blog_review_feedback"

    belongs_to :review
    before_validation do
      self.name = name.to_s.strip
      self.email = email.to_s.strip
    end
    validates :message, presence: true, length: { maximum: 10_000 }
    validates :name, length: { maximum: 100 }
    validates :email,
              length: {
                maximum: 254,
              },
              format: {
                with: URI::MailTo::EMAIL_REGEXP,
                allow_blank: true,
              }
  end
end

# == Schema Information
#
# Table name: blog_review_feedback
#
#  id         :bigint           not null, primary key
#  email      :string(254)      default(""), not null
#  message    :text             not null
#  name       :string(100)      default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  review_id  :bigint           not null
#
# Indexes
#
#  idx_blog_review_feedback_review_created  (review_id,created_at)
#
