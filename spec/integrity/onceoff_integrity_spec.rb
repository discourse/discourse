# frozen_string_literal: true

RSpec.describe ::Jobs::Onceoff do
  it "can run all once off jobs without errors" do
    # Load all once offs
    Dir[Rails.root + "app/jobs/onceoff/*.rb"].each do |f|
      require_relative "../../app/jobs/onceoff/" + File.basename(f)
    end

    ObjectSpace
      .each_object(Class)
      .select { |klass| klass.superclass == ::Jobs::Onceoff }
      .each { |job| job.new.execute_onceoff(nil) }
  end
end
