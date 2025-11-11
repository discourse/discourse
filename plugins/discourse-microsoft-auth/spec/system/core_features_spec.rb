# frozen_string_literal: true

RSpec.describe "Core features", type: :system do
  before { enable_current_plugin }

  it_behaves_like "having working core features"
end
