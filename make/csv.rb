# frozen_string_literal: true

module Make
  class Csv
    def self.all(**options)
      uk_cases **options
      uk_deaths **options
      scotland **options
      health_boards **options
      country('England', **options)
      country('Scotland', **options)
      country('Wales', **options)
      country('Northern Ireland', **options)
      nil
    end

    def self.health_boards(**options)
      ScotlandCovid19Data.health_boards.each do |health_board|
        health_board health_board, **options
      end
      nil
    end

    def self.scotland(**options)
      scotland_cases_by_health_board **options
      scotland_deaths_by_health_board **options
      scotland_icus **options
      scotland_icu_deceased **options
    end

    def self.scotland_cases_by_health_board(**options)
      $logger.info 'Writing cases CSV for Scotland.'
      headers = ['Date', *ScotlandCovid19Data.health_boards]
      data = Make::Data.scotland_cases_by_health_board
      render headers, data, filename:  "scotland_cases_per_#{NUMBERS_PER}.csv", **options
    end

    def self.scotland_deaths_by_health_board(**options)
      $logger.info 'Writing deaths CSV for Scotland.'
      headers = ['Date', *ScotlandCovid19Data.health_boards]
      data = Make::Data.scotland_deaths_by_health_board
      render headers, data, filename:  "scotland_deaths_per_#{NUMBERS_PER}.csv", **options
    end

    def self.scotland_icus(**options)
      $logger.info 'Writing ICU Beds CSV for Scotland.'
      headers = ['Date', *ScotlandCovid19Data.health_boards, 'The Golden Jubilee National Hospital']
      data = Make::Data.scotland_icus
      render headers, data, filename:  'scotland_icus.csv', **options
    end

    def self.scotland_icu_deceased(**options)
      $logger.info 'Writing ICU and deceased CSV for Scotland.'
      headers = ['Date', 'Patients in intensive care', 'Cumulative deceased']
      data = Make::Data.scotland_icu_deceased
      render headers, data, filename:  'scotland_icu_deceased.csv', **options
    end

    def self.health_board(name, **options)
      fail "#{name.inspect} is not a known health board" unless ScotlandCovid19Data.health_boards.include?(name)
      $logger.info "Writing health board CSV for #{name}."
      headers = ['Date', 'Cases', 'Deaths', 'Cases Ratio', 'Deaths Ratio']
      data = Make::Data.health_board(name)
      render headers, data, filename:  "#{name.downcase.gsub(' ', '_')}_per_#{NUMBERS_PER}.csv", **options
    end

    def self.country(name, **options)
      unless ['England', 'Scotland', 'Wales', 'Northern Ireland'].include?(name)
        fail "#{name.inspect} is not a known country"
      end

      $logger.info "Writing country CSV for #{name}."
      headers = ['Date', 'Cases', 'Deaths', 'Cases Ratio', 'Deaths Ratio']
      data = Make::Data.country(name)
      render headers, data, filename:  "#{name.downcase.gsub(' ', '_')}_per_#{NUMBERS_PER}.csv", **options
    end

    def self.uk_cases(**options)
      $logger.info 'Writing cases CSV for UK.'
      headers = ['Date', 'England Total', 'Scotland Total', 'Wales Total', 'Northern Ireland Total', 'UK Total', 'England Daily', 'Scotland Total', 'Wales Daily', 'Northern Ireland Daily', 'UK Daily']
      data = Make::Data.uk_cases
      render headers, data, filename:  "uk_cases_per_#{NUMBERS_PER}.csv", **options
    end

    def self.uk_deaths(**options)
      $logger.info 'Writing deaths CSV for UK.'
      headers = ['Date', 'England Total', 'Scotland Total', 'Wales Total', 'Northern Ireland Total', 'UK Total', 'England Daily', 'Scotland Total', 'Wales Daily', 'Northern Ireland Daily', 'UK Daily']
      data = Make::Data.uk_deaths
      render headers, data, filename:  "uk_deaths_per_#{NUMBERS_PER}.csv", **options
    end

    class << self
      private

      def render(headers, data, target: :file, filename: nil)
        csv = [headers, *data].map(&:to_csv).join

        case target
        when :file
          fail ArgumentError, 'filename must be passed when target is :file' unless filename
          File.write File.join(PUBLIC_DIR, filename), csv
        when :screen
          puts csv
        else
          fail "#{target.inspect} is not a valid target."
        end
        nil
      end
    end
  end
end
