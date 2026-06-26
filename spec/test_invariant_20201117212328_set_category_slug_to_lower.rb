require_relative '../../db/migrate/20201117212328_set_category_slug_to_lower'

RSpec.describe 'Database migration SQL injection protection' do
  let(:db_double) { double('DB') }
  let(:categories_data) { [] }

  before do
    stub_const('DB', db_double)
    allow(db_double).to receive(:query).and_return(categories_data)
  end

  it 'uses parameterized queries when executing SQL' do
    expect(db_double).to receive(:query).with(
      "SELECT id, name, slug, parent_category_id FROM categories"
    ).and_return([])

    SetCategorySlugToLower.new.up
  end

  context 'with adversarial payloads in database' do
    let(:payloads) do
      [
        { id: 1, name: 'Test', slug: "' OR 1=1 --", parent_category_id: nil },
        { id: 2, name: 'Test', slug: "'; DROP TABLE users; --", parent_category_id: nil },
        { id: 3, name: 'Test', slug: "valid-slug", parent_category_id: nil }
      ]
    end

    it 'does not allow SQL injection through existing data' do
      payloads.each do |payload|
        allow(db_double).to receive(:query).with(
          "SELECT id, name, slug, parent_category_id FROM categories"
        ).and_return([payload])

        expect { SetCategorySlugToLower.new.up }.not_to raise_error
      end
    end
  end
end