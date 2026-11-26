# frozen_string_literal: true

class Blog::Policy::Ready < Service::PolicyBase
  def call
    readiness.ready?
  end

  def reason
    readiness.error
  end

  private

  def readiness
    @readiness ||= Blog::Readiness.new(context[:publication]&.blog || Blog::Instance.default_blog)
  end
end
