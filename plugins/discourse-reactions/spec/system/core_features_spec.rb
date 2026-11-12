# frozen_string_literal: true

RSpec.describe "Core features" do
  before { enable_current_plugin }

  it_behaves_like "having working core features", skip_examples: %i[likes]
end
