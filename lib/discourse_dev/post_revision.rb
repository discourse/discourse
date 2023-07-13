# frozen_string_literal: true

require "discourse_dev/record"
require "faker"

module DiscourseDev
  class PostRevision < Record
    def initialize
      super(::PostRevision, DiscourseDev.config.post_revisions[:count])
    end

    def create!
      data = { raw: Faker::DiscourseMarkdown.sandwich(sentences: 5) }

      ::PostRevisor.new(Post.random).revise!(User.random, data)
    end

    def populate!
      @count.times { create! }
    end
  end
end
