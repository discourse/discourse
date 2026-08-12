require 'spec_helper'
require 'validation/test_validator'

describe Definitions::Validation::Test do
  subject { described_class.new }

  context 'success' do
    it 'returns true if single valid test' do
      tests = [{ "given" => { "date" => "2016-01-01", "regions" => ['us'] }, "expect" => { "name" => "Test Holiday" } } ]
      expect(subject.call(tests)).to be true
    end

    it 'returns true if multiple valid tests' do
      tests = [
        { "given" => { "date" => "2016-01-01", "regions" => ['us'] }, "expect" => { "name" => "Test Holiday" } },
        { "given" => { "date" => "2016-02-02", "regions" => ['us'] }, "expect" => { "name" => "Test 2" } }
      ]

      expect(subject.call(tests)).to be true
    end

    it 'returns true if single test has informal option' do
      tests = [{ "given" => { "date" => "2016-01-01", "regions" => ['us'], "options" => "informal" }, "expect" => { "name" => "Test Holiday" } } ]
      expect(subject.call(tests)).to be true
    end

    it 'returns true if single test has single valid option' do
      tests = [{ "given" => { "date" => "2016-01-01", "regions" => ['us'], "options" => "observed" }, "expect" => { "name" => "Test Holiday" } } ]
      expect(subject.call(tests)).to be true
    end

    it 'returns true if single test has multiple valid options' do
      tests = [{ "given" => { "date" => "2016-01-01", "regions" => ['us'], "options" => ["informal", "observed"] }, "expect" => { "name" => "Test Holiday" } } ]
      expect(subject.call(tests)).to be true
    end

    it 'returns true if regions is an array' do
      tests = [{ "given" => { "date" => "2016-01-01", "regions" => ['us', 'us_dc']}, "expect" => { "name" => "Test Holiday" } } ]
      expect(subject.call(tests)).to be true
    end

    it 'returns true if dates are an array and all are valid dates' do
      tests = [{ "given" => { "date" => ["2016-01-01", "2016-01-02", "2017-01-02"], "regions" => ['us', 'us_dc']}, "expect" => { "name" => "Test Holiday" } } ]
      expect(subject.call(tests)).to be true
    end
  end

  context 'failure' do
    it 'raises error if tests are nil' do
      expect { subject.call(nil) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
        expect(e.message).to eq "Tests cannot be nil"
      }
    end

    it 'raises error if tests are empty array' do
      expect { subject.call([]) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
        expect(e.message).to eq "Tests cannot be empty. They are too important to leave out!"
      }
    end

    it 'raises error if tests are not an array' do
      expect { subject.call("blah") }.to raise_error(Definitions::Errors::InvalidTest) { |e|
        expect(e.message).to eq "Tests must be an array"
      }
    end

    context 'single test' do
      let(:tests)  {
        [
          {
            "given" => {
              "date" => "2016-01-01",
              "regions" => ['us', 'us_dc']
            },
            "expect" => { "name" => "Test Holiday" }
          }
        ]
      }

      context 'given' do
        it 'raises error if no given value' do
          tests.first.delete("given")
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test must contain given key"
          }
        end

        it 'raises error if nil regions' do
          tests.first["given"]["regions"] = nil
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test contains invalid regions (must be an array of strings)"
          }
        end

        it 'raises error if empty regions' do
          tests.first["given"]["regions"] = []
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test must contain at least one region"
          }
        end

        it 'raises error if regions not an array' do
          tests.first["given"]["regions"] = "invalid"
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test contains invalid regions (must be an array of strings)"
          }
        end

        it 'raises error if regions is array of empty strings' do
          tests.first["given"]["regions"] = [""]
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test cannot contain empty regions"
          }
        end

        it 'raises error if single invalid option' do
          tests.first["given"]["options"] = "blah"
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test contains invalid option(s)"
          }
        end

        it 'raises error if array of options with single invalid' do
          tests.first["given"]["options"] = ["informal", "blah"]
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test contains invalid option(s)"
          }
        end

        it 'raises error if no date or year range keys' do
          tests.first["given"].delete("date")
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test must contain some date"
          }
        end

        it 'raises error if nil date' do
          tests.first["given"]["date"] = nil
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test must contain valid date"
          }
        end

        it 'raises error if invalid date' do
          tests.first["given"]["date"] = "blah"
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test must contain valid date"
          }
        end
      end

      context 'expect' do
        it 'raises error if expect key is not present' do
          tests.first.delete("expect")
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include "Test must contain expect key"
          }
        end

        it 'raises error if holiday flag value not valid' do
          tests.first["expect"]["holiday"] = "blah"
          expect { subject.call(tests) }.to raise_error(Definitions::Errors::InvalidTest) { |e|
            expect(e.message).to include"Test contains invalid holiday value (must be true/false)"
          }
        end
      end
    end
  end
end
