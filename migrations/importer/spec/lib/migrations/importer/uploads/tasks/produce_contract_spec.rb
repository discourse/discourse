# frozen_string_literal: true

# The pipeline invokes every task with `produce(emit_work:, emit_result:)`. A
# task that renames or drops one of those keywords (an underscore-prefixed
# keyword parameter does exactly that) only blows up at runtime, and the fixer
# and optimizer paths are not exercised on every run — so check the method
# signatures directly.
RSpec.describe Migrations::Importer::Uploads::Pipeline do
  shared_examples "accepting pipeline producer keywords" do |task_class:|
    it "accepts every pipeline keyword and requires no additional keywords" do
      parameters = task_class.instance_method(:produce).parameters
      accepted = parameters.filter_map { |type, name| name if %i[keyreq key].include?(type) }
      has_keyrest = parameters.any? { |type, _| type == :keyrest }

      required = parameters.filter_map { |type, name| name if type == :keyreq }

      # Everything the task requires must be provided by the pipeline's call…
      expect(required - %i[emit_work emit_result]).to be_empty
      # …and everything the pipeline passes must be accepted.
      expect(has_keyrest || (%i[emit_work emit_result] - accepted).empty?).to be(true)
    end
  end

  context "with the uploader task" do
    include_examples "accepting pipeline producer keywords",
                     task_class: Migrations::Importer::Uploads::Tasks::Uploader
  end

  context "with the optimizer task" do
    include_examples "accepting pipeline producer keywords",
                     task_class: Migrations::Importer::Uploads::Tasks::Optimizer
  end

  context "with the fixer task" do
    include_examples "accepting pipeline producer keywords",
                     task_class: Migrations::Importer::Uploads::Tasks::Fixer
  end
end
