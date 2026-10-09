require 'spec_helper'
require 'validation/month_validator'

describe Definitions::Validation::Month do
  subject { described_class.new }

  context 'months are valid' do
    it 'reports success' do
      months =  { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1}] }
      expect(subject.call(months)).to be true
    end
  end

  context 'invalid months' do
    it 'returns error if missing' do
      expect { subject.call(nil) }.to raise_error(Definitions::Errors::NoMonths)
    end

    it 'returns error if empty' do
      expect { subject.call({}) }.to raise_error(Definitions::Errors::NoMonths)
      expect { subject.call([]) }.to raise_error(Definitions::Errors::NoMonths)
    end

    it 'returns error if month not an integer' do
      months = { 'january' => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1}] }
      expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
        expect(e.message).to eq("All months must be an integer, received: #{months}")
      }
    end

    it 'returns error if months not 0 through 12' do
      months = { -1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1}] }
      expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
        expect(e.message).to eq("All months must be between 0 and 12, received: #{months}")
      }

      months = { 13 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1}] }
      expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
        expect(e.message).to eq("All months must be between 0 and 12, received: #{months}")
      }
    end

    it 'returns error if month has no name' do
      months = { 1 => [{""=>"Test Holiday", "regions"=>["test"], "mday"=>1}] }
      expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
        expect(e.message).to eq("All months must have a name, received: #{months}")
      }
    end

    it 'returns error if month has no regions' do
      months = { 1 => [{"name"=>"Test Holiday", "mday"=>1}] }
      expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidRegions) { |e|
        expect(e.message).to eq("A month must contain at least one region, received: #{months}")
      }
    end

    it 'returns error if month has empty regions' do
      months = { 1 => [{"name"=>"Test Holiday", "regions" => [], "mday"=>1}] }
      expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidRegions) { |e|
        expect(e.message).to eq("A month must contain at least one region, received: #{months}")
      }
    end

    it 'returns error if month has empty regions' do
      months = { 1 => [{"name"=>"Test Holiday", "regions"=>[""], "mday"=>1}] }
      expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidRegions) { |e|
        expect(e.message).to eq("A month must contain at least one region, received: #{months}")
      }
    end

    context 'year_ranges' do
      it 'returns error if year_ranges contains unknown subkey' do
        months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"blah" => [2018]} }] }
        expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
          expect(e.message).to eq("The :year_ranges value only accepts the following: :until, :from, :limited, :between, received: #{months}")
        }
      end

      it 'returns error if :until value is not a single integer' do
        months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"until" => [2018]} }] }
        expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
          expect(e.message).to eq("The year_ranges.until value must contain a single 'year' integer, ex. 2018, received: #{months}")
        }
      end

      it 'returns error if :from value is not a single integer' do
        months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"from" => [2018]} }] }
        expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
          expect(e.message).to eq("The year_ranges.from value must contain a single 'year' integer, ex. 2018, received: #{months}")
        }
      end

      it 'returns error if :limited value is not an array' do
        months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"limited" => 2018} }] }
        expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
          expect(e.message).to eq("The year_ranges.limited value must contain an array of 'year' integers, ex. [2018], received: #{months}")
        }
      end

      it 'returns error if :limited value is not an array of integers' do
        months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"limited" => ["blah"]} }] }
        expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
          expect(e.message).to eq("The year_ranges.limited value must contain an array of 'year' integers, ex. [2018], received: #{months}")
        }
      end

      context 'between' do
        it 'returns error if not a hash' do
          months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"between" => "2008..2012" } }] }
          expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
            expect(e.message).to eq("year_ranges.between must contain both a 'start' and 'end' key, received: #{months}")
          }
        end

        it 'returns error if start is missing' do
          months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"between" => {"end" => 2018} } }] }
          expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
            expect(e.message).to eq("year_ranges.between must contain both a 'start' and 'end' key, received: #{months}")
          }
        end

        it 'returns error if end is missing' do
          months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"between" => {"start" => 2016} } }] }
          expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
            expect(e.message).to eq("year_ranges.between must contain both a 'start' and 'end' key, received: #{months}")
          }
        end

        it 'returns an error if start value is not an integer' do
          months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"between" => {"start" => "2016", "end" => 2018} } }] }
          expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
            expect(e.message).to eq("The year_ranges.between.start value must contain a single 'year' integer, ex. 2018, received: #{months}")
          }
        end

        it 'returns an error if end value is not an integer' do
          months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"between" => {"start" => 2016, "end" => "2018"} } }] }
          expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
            expect(e.message).to eq("The year_ranges.between.end value must contain a single 'year' integer, ex. 2018, received: #{months}")
          }
        end

        it 'returns an error if end value is before start' do
          months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"between" => {"start" => 2016, "end" => 2015} } }] }
          expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
            expect(e.message).to eq("The year_ranges.between.end value cannot be before the start value, received: #{months}")
          }
        end

        it 'returns an error if the start and end values are the same' do
          months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"between" => {"start" => 2016, "end" => 2016} } }] }
          expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
            expect(e.message).to eq("The year_ranges.between start and end values cannot be the same, received: #{months}")
          }
        end
      end

      context 'with multiple selectors' do
        it 'returns an error if provided an array' do
          months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => [{"from" => 2019}, {"between" => {"start" => 2014, "end" => 2016} }] }] }
          expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
            expect(e.message).to eq("year_ranges only supports a single selector at this time, received: #{months}")
          }
        end

        it 'returns an error if there is more than 1 sub key' do
          months = { 1 => [{"name"=>"Test Holiday", "regions"=>["test"], "mday"=>1, "year_ranges" => {"from" => 2019, "between" => {"start" => 2014, "end" => 2016} } }] }
          expect { subject.call(months) }.to raise_error(Definitions::Errors::InvalidMonth) { |e|
            expect(e.message).to eq("year_ranges only supports a single selector at this time, received: #{months}")
          }
        end
      end
    end
  end
end
