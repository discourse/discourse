# frozen_string_literal: true

require "discourse_dev/reviewable"
require "faker"

module DiscourseDev
  class ReviewablePost < Reviewable
    def populate!
      @posts.sample(2).each { |post| ::ReviewablePost.queue_for_review(post) }
    end
  end
end
