# frozen_string_literal: true

RSpec.describe "Testing core features", type: :system do
  it_behaves_like "having working core features", skip_examples: %i[search]
end
