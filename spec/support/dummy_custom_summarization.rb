# frozen_string_literal: true

class DummyCustomSummarization < Summarization::Base
  def initialize(summarization_result)
    @summarization_result = summarization_result
  end

  def display_name
    "dummy"
  end

  def correctly_configured?
    true
  end

  def configuration_hint
    "hint"
  end

  def model
    "dummy"
  end

  def summarize(_content)
    @summarization_result.tap { |result| yield(result[:summary]) if block_given? }
  end
end
