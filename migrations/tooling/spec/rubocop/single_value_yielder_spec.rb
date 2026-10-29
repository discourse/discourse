# frozen_string_literal: true

require_relative "../../rubocop/single_value_yielder"
require "rubocop/rspec/cop_helper"
require "rubocop/rspec/expect_offense"

RSpec.describe RuboCop::Cop::Migrations::SingleValueYielder do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }
  let(:ruby_version) { 3.4 }

  it "reports a single positional value on an Enumerator's named yielder" do
    expect_offense(<<~RUBY)
      ::Enumerator.new(10) do |output|
        rows.each do |row|
          output.yield(row)
                 ^^^^^ #{described_class.cop_name}: #{described_class::MSG}
        end
      end
    RUBY
    expect_no_corrections
  end

  it "reports a single array or explicitly positional hash" do
    expect_offense(<<~RUBY)
      Enumerator.new do |output|
        output.yield([key, value])
               ^^^^^ #{described_class.cop_name}: #{described_class::MSG}
        output.yield({key: value})
               ^^^^^ #{described_class.cop_name}: #{described_class::MSG}
      end
    RUBY
  end

  it "allows keywords, splats, and multiple or zero arguments" do
    expect_no_offenses(<<~RUBY)
      Enumerator.new do |output|
        output.yield
        output.yield(key, value)
        output.yield(key: value)
        output.yield(**options)
        output.yield(*values)
        output.yield(row, &callback)
      end
    RUBY
  end

  it "allows explicitly consumed return values and block-result transformations" do
    expect_no_offenses(<<~RUBY)
      Enumerator.new do |output|
        response = output.yield(row)
        consume(output.yield(row))
        break if output.yield(row)
        rows.map { |row| output.yield(row) }
        return output.yield(row)
      end
    RUBY
  end

  it "allows unrelated objects and shadowed or reassigned variables" do
    expect_no_offenses(<<~RUBY)
      other.yield(row)
      Something::Enumerator.new { |output| output.yield(row) }
      Enumerator.new do |output|
        rows.each { |output| output.yield(row) }
        rows.each { |row; output| output.yield(row) }
        def unrelated(output)
          output.yield(row)
        end
      end
      Enumerator.new do |output|
        output = other
        output.yield(row)
      end
    RUBY
  end

  it "leaves Ruby yield and the single-value push API alone" do
    expect_no_offenses(<<~RUBY)
      def each_row
        yield row
      end
      Enumerator.new { |output| output << row }
    RUBY
  end
end
