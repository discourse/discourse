# frozen_string_literal: true

class DummyCustomSummarization < Summarization::Base
  RESPONSE = "This is a summary of the content you gave me"

  def display_name
    "dummy"
  end

  def correctly_configured?
    true
  end

  def configuration_hint
    "hint"
  end

  def summarize(_content)
    RESPONSE
  end
end
