# frozen_string_literal: true
class UpdateOpenAiEmbeddingsTokenizer < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE embedding_definitions
      SET tokenizer_class = 'DiscourseAi::Tokenizer::OpenAiCl100kTokenizer'
      WHERE url LIKE '%https://api.openai.com/%' AND tokenizer_class <> 'DiscourseAi::Tokenizer::OpenAiCl100kTokenizer'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
