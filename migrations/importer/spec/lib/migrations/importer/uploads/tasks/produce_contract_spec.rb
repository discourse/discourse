# frozen_string_literal: true

# The pipeline invokes every task with `produce(emit_work:, emit_result:)`. A
# task that renames or drops one of those keywords (an underscore-prefixed
# keyword parameter does exactly that) only blows up at runtime, and the fixer
# and optimizer paths are not exercised on every run — so check the method
# signatures directly.
RSpec.describe Migrations::Importer::Uploads::Pipeline do
  it "#{Migrations::Importer::Uploads::Tasks::Uploader.name.demodulize} accepts the pipeline's produce keywords" do
    parameters = Migrations::Importer::Uploads::Tasks::Uploader.instance_method(:produce).parameters
    accepted = parameters.filter_map { |type, name| name if %i[keyreq key].include?(type) }
    has_keyrest = parameters.any? { |type, _| type == :keyrest }

    required = parameters.filter_map { |type, name| name if type == :keyreq }

    # Everything the task requires must be provided by the pipeline's call…
    expect(required - %i[emit_work emit_result]).to be_empty
    # …and everything the pipeline passes must be accepted.
    expect(has_keyrest || (%i[emit_work emit_result] - accepted).empty?).to be(true)
  end

  it "#{Migrations::Importer::Uploads::Tasks::Optimizer.name.demodulize} accepts the pipeline's produce keywords" do
    parameters =
      Migrations::Importer::Uploads::Tasks::Optimizer.instance_method(:produce).parameters
    accepted = parameters.filter_map { |type, name| name if %i[keyreq key].include?(type) }
    has_keyrest = parameters.any? { |type, _| type == :keyrest }

    required = parameters.filter_map { |type, name| name if type == :keyreq }

    # Everything the task requires must be provided by the pipeline's call…
    expect(required - %i[emit_work emit_result]).to be_empty
    # …and everything the pipeline passes must be accepted.
    expect(has_keyrest || (%i[emit_work emit_result] - accepted).empty?).to be(true)
  end

  it "#{Migrations::Importer::Uploads::Tasks::Fixer.name.demodulize} accepts the pipeline's produce keywords" do
    parameters = Migrations::Importer::Uploads::Tasks::Fixer.instance_method(:produce).parameters
    accepted = parameters.filter_map { |type, name| name if %i[keyreq key].include?(type) }
    has_keyrest = parameters.any? { |type, _| type == :keyrest }

    required = parameters.filter_map { |type, name| name if type == :keyreq }

    # Everything the task requires must be provided by the pipeline's call…
    expect(required - %i[emit_work emit_result]).to be_empty
    # …and everything the pipeline passes must be accepted.
    expect(has_keyrest || (%i[emit_work emit_result] - accepted).empty?).to be(true)
  end
end
