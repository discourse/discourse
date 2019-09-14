# frozen_string_literal: true

require "rails_helper"

describe OnceoffBase do
  it "can run all once off jobs without errors" do
    # load all once offs

    Dir[Rails.root + 'app/jobs/onceoff/*.rb'].each do |f|
      require_relative '../../app/jobs/onceoff/' + File.basename(f)
    end
    ObjectSpace.each_object(Class).select { |klass| klass < OnceoffBase }.each do |j|
      j.new.execute_onceoff(nil)
    end
  end
end
