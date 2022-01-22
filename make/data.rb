# frozen_string_literal: true

module Make
  class Data
    def self.scotland_cases_by_health_board
      health_boards = ScotlandCovid19Data.health_boards
      cases = ScotlandCovid19Data.cases

      cases.keys.sort.map do |date|
        [date, *cases.fetch(date).values_at(*health_boards, 'Grand Total')]
      end
    end

    def self.scotland_deaths_by_health_board
      health_boards = ScotlandCovid19Data.health_boards
      deaths = ScotlandCovid19Data.deaths

      deaths.keys.sort.map do |date|
        [date, *deaths.fetch(date).values_at(*health_boards, 'Grand Total')]
      end
    end

    def self.scotland_icus
      health_boards = [*ScotlandCovid19Data.health_boards, 'The Golden Jubilee National Hospital']
      icus = ScotlandCovid19Data.intensive_cares

      icus.keys.sort.map do |date|
        [date, *icus.fetch(date).values_at(*health_boards, 'Grand Total')]
      end
    end

    def self.scotland_icu_deceased
      intensive_care = ScotlandCovid19Data.intensive_care
      deceased = ScotlandCovid19Data.deceased

      earliest_date = [deceased.keys.min, intensive_care.keys.min].min
      latest_date = [deceased.keys.max, intensive_care.keys.max].max

      (earliest_date..latest_date).map do |date|
        [date, intensive_care[date], deceased[date]]
      end
    end

    def self.health_board(name)
      fail "#{name.inspect} is not a known health board" unless ScotlandCovid19Data.health_boards.include?(name)

      cases = ScotlandCovid19Data.cases
      deaths = ScotlandCovid19Data.deaths
      earliest_date = [cases.keys.min, deaths.keys.min].min
      latest_date = [cases.keys.max, deaths.keys.max].max

      (earliest_date..latest_date).map do |date|
        [
          date,
          cases.dig(date, name),
          deaths.dig(date, name),
          cases.dig(date, name) ? cases.dig(date, name) / cases.dig(date, 'Grand Total') : nil,
          deaths.dig(date, name) ? deaths.dig(date, name) / deaths.dig(date, 'Grand Total') : nil
        ]
      end
    end

    def self.country(name)
      unless ['England', 'Scotland', 'Wales', 'Northern Ireland'].include?(name)
        fail "#{name.inspect} is not a known country"
      end

      uk = UkCovid19Data.uk
      country = UkCovid19Data.send name.downcase.gsub(' ', '_')
      start_date = [uk.keys.min, country.keys.min].max
      finish_date = [uk.keys.max, country.keys.max].min

      (start_date..finish_date).map do |date|
        do_cases = uk.dig(date, :daily_cases) && country.dig(date, :daily_cases)
        do_deaths = uk.dig(date, :daily_deaths) && country.dig(date, :daily_deaths)

        [
          date,
          country.dig(date, :daily_cases),
          country.dig(date, :daily_deaths),
          do_cases ? country.dig(date, :daily_cases) / uk.dig(date, :daily_cases) : nil,
          do_deaths ? country.dig(date, :daily_deaths) / uk.dig(date, :daily_deaths) : nil
        ]
      end
    end

    def self.uk_cases
      uk = UkCovid19Data.uk
      england = UkCovid19Data.england
      scotland = UkCovid19Data.scotland
      wales = UkCovid19Data.wales
      northern_ireland = UkCovid19Data.northern_ireland
      start_date = [england.keys.min, scotland.keys.min, wales.keys.min, northern_ireland.keys.min].min
      finish_date = [england.keys.max, scotland.keys.max, wales.keys.max, northern_ireland.keys.max].max

      (start_date..finish_date).map do |date|
        [
          date,
          england.dig(date, :cumulative_cases),
          scotland.dig(date, :cumulative_cases),
          wales.dig(date, :cumulative_cases),
          northern_ireland.dig(date, :cumulative_cases),
          uk.dig(date, :cumulative_cases),
          england.dig(date, :daily_cases),
          scotland.dig(date, :daily_cases),
          wales.dig(date, :daily_cases),
          northern_ireland.dig(date, :daily_cases),
          uk.dig(date, :daily_cases)
        ]
      end
    end

    def self.uk_deaths
      uk = UkCovid19Data.uk
      england = UkCovid19Data.england
      scotland = UkCovid19Data.scotland
      wales = UkCovid19Data.wales
      northern_ireland = UkCovid19Data.northern_ireland
      start_date = [england.keys.min, scotland.keys.min, wales.keys.min, northern_ireland.keys.min].min
      finish_date = [england.keys.max, scotland.keys.max, wales.keys.max, northern_ireland.keys.max].max

      (start_date..finish_date).map do |date|
        [
          date,
          england.dig(date, :cumulative_deaths),
          scotland.dig(date, :cumulative_deaths),
          wales.dig(date, :cumulative_deaths),
          northern_ireland.dig(date, :cumulative_deaths),
          uk.dig(date, :cumulative_deaths),
          england.dig(date, :daily_deaths),
          scotland.dig(date, :daily_deaths),
          wales.dig(date, :daily_deaths),
          northern_ireland.dig(date, :daily_deaths),
          uk.dig(date, :daily_deaths)
        ]
      end
    end

    def self.mobility
      GoogleMobilityData.data
    end

    def self.mobility_uk
      GoogleMobilityData.data['UK']
    end

    def self.mobility_scotland
      GoogleMobilityData.data['Scotland']
    end
  end
end
