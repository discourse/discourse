# frozen_string_literal: true

RSpec.describe "Breton plural rules", type: :integration do # rubocop:disable RSpec/DescribeClass
  let(:br_plural_rule) do
    plurals = eval(File.read(Rails.root.join("config/locales/plurals.rb"))) # rubocop:disable Security/Eval
    plurals[:br][:i18n][:plural][:rule]
  end

  # Per CLDR: https://unicode.org/cldr/charts/45/supplemental/language_plural_rules.html
  # few: n % 10 = 3..4,9 and n % 100 != 10..19,70..79,90..99
  describe ":few category" do
    it "returns :few for n % 10 in 3,4,9 when n % 100 not in excluded ranges" do
      [3, 4, 9, 23, 24, 29, 43, 44, 49, 103, 104, 109].each do |n|
        expect(br_plural_rule.call(n)).to eq(:few), "Expected #{n} to be :few"
      end
    end

    it "returns :other for n % 10 in 3,4,9 when n % 100 IS in 10..19" do
      [13, 14, 19].each do |n|
        expect(br_plural_rule.call(n)).to eq(:other),
        "Expected #{n} to be :other (n % 100 in 10..19)"
      end
    end

    it "returns :other for n % 10 in 3,4,9 when n % 100 IS in 70..79" do
      [73, 74, 79].each do |n|
        expect(br_plural_rule.call(n)).to eq(:other),
        "Expected #{n} to be :other (n % 100 in 70..79)"
      end
    end

    it "returns :other for n % 10 in 3,4,9 when n % 100 IS in 90..99" do
      [93, 94, 99].each do |n|
        expect(br_plural_rule.call(n)).to eq(:other),
        "Expected #{n} to be :other (n % 100 in 90..99)"
      end
    end
  end
end
