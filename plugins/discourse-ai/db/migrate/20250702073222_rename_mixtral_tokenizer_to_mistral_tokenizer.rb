# frozen_string_literal: true

class RenameMixtralTokenizerToMistralTokenizer < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE
        llm_models
      SET
        tokenizer = 'DiscourseAi::Tokenizer::Mistral'
      WHERE
        tokenizer = 'DiscourseAi::Tokenizer::Mixtral'
    SQL

    execute <<~SQL
      UPDATE
        embedding_definitions
      SET
        tokenizer_class = 'DiscourseAi::Tokenizer::Mistral'
      WHERE
        tokenizer_class = 'DiscourseAi::Tokenizer::Mixtral'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE
        llm_models
      SET
        tokenizer = 'DiscourseAi::Tokenizer::Mixtral'
      WHERE
        tokenizer = 'DiscourseAi::Tokenizer::Mistral'
    SQL

    execute <<~SQL
      UPDATE
        embedding_definitions
      SET
        tokenizer_class = 'DiscourseAi::Tokenizer::Mixtral'
      WHERE
        tokenizer_class = 'DiscourseAi::Tokenizer::Mistral'
    SQL
  end
end
